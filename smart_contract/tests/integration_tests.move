#[test_only]
module skillshare_addr::integration_tests {
    use skillshare_addr::skillshare;
    use skillshare_addr::test_helpers;
    use aptos_framework::coin;
    use aptos_framework::aptos_coin::AptosCoin;
    use aptos_framework::timestamp;
    use std::signer;
    use std::vector;

    // ==================== COMPLETE USER JOURNEY TESTS ====================

    #[test(admin = @skillshare_addr, alice = @0xa, bob = @0xb, framework = @aptos_framework)]
    fun test_complete_happy_path_flow(admin: &signer, alice: &signer, bob: &signer, framework: &signer) {
        timestamp::set_time_has_started_for_testing(framework);
        test_helpers::setup_test_environment(admin);
        
        // Step 1: User Registration & Profile Setup
        test_helpers::register_user_with_default_contact(alice, b"Alice_Learner", b"alice");
        test_helpers::register_user_with_default_contact(bob, b"Bob_Teacher", b"bob");
        
        // Step 2: Skill Addition (Teachers showcase their expertise)
        skillshare::add_skill(bob, b"React Development");
        skillshare::add_skill(bob, b"JavaScript");
        skillshare::add_skill(bob, b"Node.js");
        skillshare::add_skill(alice, b"Python"); // Alice can also be a teacher
        
        // Step 3: Discovery & Request (Alice finds Bob's skills)
        let alice_addr = signer::address_of(alice);
        let bob_addr = signer::address_of(bob);
        
        // Verify users can see each other exist
        assert!(skillshare::user_exists(alice_addr), 301);
        assert!(skillshare::user_exists(bob_addr), 302);
        
        // Step 4: Teaching Request Creation
        skillshare::request_teach(alice, bob_addr, b"React Development");
        
        // Step 5: Teacher Acceptance
        skillshare::accept_request(bob, 1);
        
        // Step 6: Payment Setup & Deposit
        test_helpers::setup_coin_balance(alice, 200000000); // 2 APT for payment + gas
        let alice_initial_balance = coin::balance<AptosCoin>(alice_addr);
        let bob_initial_balance = coin::balance<AptosCoin>(bob_addr);
        
        skillshare::deposit_payment(alice, 1);
        
        // Verify payment deducted from learner
        let alice_after_payment = coin::balance<AptosCoin>(alice_addr);
        assert!(alice_initial_balance - alice_after_payment == 100000000, 303); // 1 APT deducted
        
        // Step 7: Teacher Payment Acknowledgment & Contact Exchange
        skillshare::acknowledge_payment(bob, 1);
        
        // Verify contact information becomes accessible
        let alice_contact = skillshare::get_contact_info(1, bob_addr);
        let bob_contact = skillshare::get_contact_info(1, alice_addr);
        assert!(!vector::is_empty(&alice_contact), 304);
        assert!(!vector::is_empty(&bob_contact), 305);
        
        // Step 8: Communication Initiation
        skillshare::learner_mark_communication_started(alice, 1);
        
        // Step 9: Lesson Delivery Simulation (off-chain teaching occurs)
        // In real scenario: Alice and Bob coordinate via Discord/Email
        
        // Step 10: Lesson Completion Process
        skillshare::teacher_request_release(bob, 1);
        skillshare::learner_confirm_completion(alice, admin, 1);
        
        // Step 11: Final Verification
        let bob_final_balance = coin::balance<AptosCoin>(bob_addr);
        assert!(bob_final_balance - bob_initial_balance == 100000000, 306); // Bob received 1 APT
        
        // Verify both users can still access contact info post-completion
        let final_alice_contact = skillshare::get_contact_info(1, bob_addr);
        assert!(!vector::is_empty(&final_alice_contact), 307);
    }

    #[test(admin = @skillshare_addr, alice = @0xa, bob = @0xb, framework = @aptos_framework)]
    fun test_non_responsive_teacher_complete_flow(admin: &signer, alice: &signer, bob: &signer, framework: &signer) {
        timestamp::set_time_has_started_for_testing(framework);
        test_helpers::setup_test_environment(admin);
        
        // Step 1-6: Same as happy path up to payment
        test_helpers::register_user_with_default_contact(alice, b"Alice_Learner", b"alice");
        test_helpers::register_user_with_default_contact(bob, b"Bob_Teacher", b"bob");
        skillshare::add_skill(bob, b"Solidity");
        
        skillshare::request_teach(alice, signer::address_of(bob), b"Solidity");
        skillshare::accept_request(bob, 1);
        
        test_helpers::setup_coin_balance(alice, 200000000);
        let alice_initial_balance = coin::balance<AptosCoin>(signer::address_of(alice));
        
        skillshare::deposit_payment(alice, 1);
        skillshare::acknowledge_payment(bob, 1);
        
        // Step 7: Teacher Becomes Non-Responsive (doesn't contact learner)
        // Alice waits for teacher contact but none comes
        
        // Step 8: Time Passes (25 hours - past 24-hour deadline)
        test_helpers::advance_time_by_hours(25);
        
        // Step 9: Learner Reports Non-Response
        skillshare::learner_report_non_response(alice, 1);
        
        // Step 10: Refund Process
        skillshare::claim_refund(alice, admin, 1);
        
        // Step 11: Verify Full Refund
        let alice_final_balance = coin::balance<AptosCoin>(signer::address_of(alice));
        assert!(alice_final_balance == alice_initial_balance, 308); // Full refund received
        
        // Step 12: Verify Contact Access Still Available (for dispute resolution)
        let contact_info = skillshare::get_contact_info(1, signer::address_of(alice));
        assert!(!vector::is_empty(&contact_info), 309);
    }

    // ==================== MULTI-USER INTERACTION TESTS ====================

    #[test(admin = @skillshare_addr, alice = @0xa, bob = @0xb, charlie = @0xc, framework = @aptos_framework)]
    fun test_one_learner_multiple_teachers_flow(admin: &signer, alice: &signer, bob: &signer, charlie: &signer, framework: &signer) {
        timestamp::set_time_has_started_for_testing(framework);
        test_helpers::setup_test_environment(admin);
        
        // Setup: One learner (Alice) wants to learn multiple skills from different teachers
        test_helpers::register_user_with_default_contact(alice, b"Alice_MultiLearner", b"alice");
        test_helpers::register_user_with_default_contact(bob, b"Bob_ReactTeacher", b"bob");
        test_helpers::register_user_with_default_contact(charlie, b"Charlie_SolidityTeacher", b"charlie");
        
        skillshare::add_skill(bob, b"React");
        skillshare::add_skill(charlie, b"Solidity");
        
        // Alice requests both skills
        skillshare::request_teach(alice, signer::address_of(bob), b"React");
        skillshare::request_teach(alice, signer::address_of(charlie), b"Solidity");
        
        // Both teachers accept
        skillshare::accept_request(bob, 1);
        skillshare::accept_request(charlie, 2);
        
        // Alice pays for both lessons
        test_helpers::setup_coin_balance(alice, 400000000); // 4 APT for both + gas
        let alice_initial = coin::balance<AptosCoin>(signer::address_of(alice));
        
        skillshare::deposit_payment(alice, 1);
        skillshare::deposit_payment(alice, 2);
        
        // Verify both payments deducted
        let alice_after_payments = coin::balance<AptosCoin>(signer::address_of(alice));
        assert!(alice_initial - alice_after_payments == 200000000, 310); // 2 APT total
        
        // Both teachers acknowledge
        skillshare::acknowledge_payment(bob, 1);
        skillshare::acknowledge_payment(charlie, 2);
        
        // Alice can access both teachers' contact info
        let bob_contact = skillshare::get_contact_info(1, signer::address_of(alice));
        let charlie_contact = skillshare::get_contact_info(2, signer::address_of(alice));
        assert!(!vector::is_empty(&bob_contact), 311);
        assert!(!vector::is_empty(&charlie_contact), 312);
        
        // Alice starts communication with both
        skillshare::learner_mark_communication_started(alice, 1);
        skillshare::learner_mark_communication_started(alice, 2);
        
        // Complete both lessons
        skillshare::teacher_request_release(bob, 1);
        skillshare::teacher_request_release(charlie, 2);
        skillshare::learner_confirm_completion(alice, admin, 1);
        skillshare::learner_confirm_completion(alice, admin, 2);
        
        // Verify both teachers received payment
        test_helpers::assert_balance_at_least(signer::address_of(bob), 100000000);
        test_helpers::assert_balance_at_least(signer::address_of(charlie), 100000000);
    }

    #[test(admin = @skillshare_addr, alice = @0xa, bob = @0xb, charlie = @0xc, framework = @aptos_framework)]
    fun test_one_teacher_multiple_learners_flow(admin: &signer, alice: &signer, bob: &signer, charlie: &signer, framework: &signer) {
        timestamp::set_time_has_started_for_testing(framework);
        test_helpers::setup_test_environment(admin);
        
        // Setup: One expert teacher (Bob) with multiple learners
        test_helpers::register_user_with_default_contact(alice, b"Alice_Student", b"alice");
        test_helpers::register_user_with_default_contact(bob, b"Bob_ExpertTeacher", b"bob");
        test_helpers::register_user_with_default_contact(charlie, b"Charlie_Student", b"charlie");
        
        skillshare::add_skill(bob, b"Advanced_React");
        
        // Both learners request the same skill
        skillshare::request_teach(alice, signer::address_of(bob), b"Advanced_React");
        skillshare::request_teach(charlie, signer::address_of(bob), b"Advanced_React");
        
        // Teacher accepts both requests
        skillshare::accept_request(bob, 1);
        skillshare::accept_request(bob, 2);
        
        // Both learners pay
        test_helpers::setup_coin_balance(alice, 200000000);
        test_helpers::setup_coin_balance(charlie, 200000000);
        
        skillshare::deposit_payment(alice, 1);
        skillshare::deposit_payment(charlie, 2);
        
        // Teacher acknowledges both payments
        skillshare::acknowledge_payment(bob, 1);
        skillshare::acknowledge_payment(bob, 2);
        
        // Teacher can access both learners' contact info
        let alice_contact = skillshare::get_contact_info(1, signer::address_of(bob));
        let charlie_contact = skillshare::get_contact_info(2, signer::address_of(bob));
        assert!(!vector::is_empty(&alice_contact), 313);
        assert!(!vector::is_empty(&charlie_contact), 314);
        
        // Both learners confirm communication started
        skillshare::learner_mark_communication_started(alice, 1);
        skillshare::learner_mark_communication_started(charlie, 2);
        
        // Complete both lessons
        skillshare::teacher_request_release(bob, 1);
        skillshare::teacher_request_release(bob, 2);
        skillshare::learner_confirm_completion(alice, admin, 1);
        skillshare::learner_confirm_completion(charlie, admin, 2);
        
        // Verify teacher received both payments (2 APT total)
        test_helpers::assert_balance_at_least(signer::address_of(bob), 200000000);
    }

    // ==================== COMPLEX TIMING SCENARIOS ====================

    #[test(admin = @skillshare_addr, alice = @0xa, bob = @0xb, framework = @aptos_framework)]
    fun test_mixed_outcome_scenario(admin: &signer, alice: &signer, bob: &signer, framework: &signer) {
        timestamp::set_time_has_started_for_testing(framework);
        test_helpers::setup_test_environment(admin);
        
        // Scenario: Alice requests multiple skills, some succeed, some fail
        test_helpers::register_user_with_default_contact(alice, b"Alice_MixedLearner", b"alice");
        test_helpers::register_user_with_default_contact(bob, b"Bob_MixedTeacher", b"bob");
        
        skillshare::add_skill(bob, b"JavaScript");
        skillshare::add_skill(bob, b"Python");
        
        // Alice requests both skills
        skillshare::request_teach(alice, signer::address_of(bob), b"JavaScript");
        skillshare::request_teach(alice, signer::address_of(bob), b"Python");
        
        skillshare::accept_request(bob, 1);
        skillshare::accept_request(bob, 2);
        
        // Alice pays for both
        test_helpers::setup_coin_balance(alice, 400000000);
        let alice_initial = coin::balance<AptosCoin>(signer::address_of(alice));
        
        skillshare::deposit_payment(alice, 1);
        skillshare::deposit_payment(alice, 2);
        
        // Teacher acknowledges both
        skillshare::acknowledge_payment(bob, 1);
        skillshare::acknowledge_payment(bob, 2);
        
        // First lesson proceeds normally
        skillshare::learner_mark_communication_started(alice, 1);
        skillshare::teacher_request_release(bob, 1);
        skillshare::learner_confirm_completion(alice, admin, 1);
        
        // Second lesson - teacher becomes non-responsive
        test_helpers::advance_time_by_hours(25);
        skillshare::learner_report_non_response(alice, 2);
        skillshare::claim_refund(alice, admin, 2);
        
        // Final verification: Alice paid for one lesson, got refund for other
        let alice_final = coin::balance<AptosCoin>(signer::address_of(alice));
        assert!(alice_initial - alice_final == 100000000, 315); // Net: paid 1 APT
        
        // Teacher received payment for completed lesson only
        test_helpers::assert_balance_at_least(signer::address_of(bob), 100000000);
    }

    #[test(admin = @skillshare_addr, alice = @0xa, bob = @0xb, framework = @aptos_framework)]
    fun test_immediate_completion_flow(admin: &signer, alice: &signer, bob: &signer, framework: &signer) {
        timestamp::set_time_has_started_for_testing(framework);
        test_helpers::setup_test_environment(admin);
        
        // Scenario: Very quick lesson completion (no delays)
        test_helpers::register_user_with_default_contact(alice, b"Alice_QuickLearner", b"alice");
        test_helpers::register_user_with_default_contact(bob, b"Bob_QuickTeacher", b"bob");
        
        skillshare::add_skill(bob, b"Quick_Tutorial");
        
        // Rapid-fire completion
        skillshare::request_teach(alice, signer::address_of(bob), b"Quick_Tutorial");
        skillshare::accept_request(bob, 1);
        
        test_helpers::setup_coin_balance(alice, 200000000);
        skillshare::deposit_payment(alice, 1);
        skillshare::acknowledge_payment(bob, 1);
        
        // Immediate communication and completion
        skillshare::learner_mark_communication_started(alice, 1);
        skillshare::teacher_request_release(bob, 1);
        skillshare::learner_confirm_completion(alice, admin, 1);
        
        // Verify rapid completion works correctly
        test_helpers::assert_balance_at_least(signer::address_of(bob), 100000000);
    }

    // ==================== ERROR RECOVERY SCENARIOS ====================

    #[test(admin = @skillshare_addr, alice = @0xa, bob = @0xb, framework = @aptos_framework)]
    fun test_late_communication_recovery(admin: &signer, alice: &signer, bob: &signer, framework: &signer) {
        timestamp::set_time_has_started_for_testing(framework);
        test_helpers::setup_test_environment(admin);
        
        // Scenario: Teacher contacts learner after 24-hour deadline but before non-response report
        test_helpers::register_user_with_default_contact(alice, b"Alice_PatientLearner", b"alice");
        test_helpers::register_user_with_default_contact(bob, b"Bob_LateTeacher", b"bob");
        
        skillshare::add_skill(bob, b"Complex_Subject");
        
        skillshare::request_teach(alice, signer::address_of(bob), b"Complex_Subject");
        skillshare::accept_request(bob, 1);
        
        test_helpers::setup_coin_balance(alice, 200000000);
        skillshare::deposit_payment(alice, 1);
        skillshare::acknowledge_payment(bob, 1);
        
        // Time passes beyond 24 hours
        test_helpers::advance_time_by_hours(30);
        
        // But learner is patient and teacher finally contacts them
        skillshare::learner_mark_communication_started(alice, 1);
        
        // Lesson proceeds normally despite late start
        skillshare::teacher_request_release(bob, 1);
        skillshare::learner_confirm_completion(alice, admin, 1);
        
        // Verify late recovery works
        test_helpers::assert_balance_at_least(signer::address_of(bob), 100000000);
    }

    // ==================== COMPREHENSIVE END-TO-END VALIDATION ====================

    #[test(admin = @skillshare_addr, alice = @0xa, bob = @0xb, charlie = @0xc, framework = @aptos_framework)]
    fun test_full_platform_ecosystem(admin: &signer, alice: &signer, bob: &signer, charlie: &signer, framework: &signer) {
        timestamp::set_time_has_started_for_testing(framework);
        test_helpers::setup_test_environment(admin);
        
        // Comprehensive scenario: All users are both teachers and learners
        test_helpers::register_user_with_default_contact(alice, b"Alice_FullUser", b"alice");
        test_helpers::register_user_with_default_contact(bob, b"Bob_FullUser", b"bob");
        test_helpers::register_user_with_default_contact(charlie, b"Charlie_FullUser", b"charlie");
        
        // Each user has different skills
        skillshare::add_skill(alice, b"Python");
        skillshare::add_skill(alice, b"Data_Science");
        skillshare::add_skill(bob, b"React");
        skillshare::add_skill(bob, b"Node.js");
        skillshare::add_skill(charlie, b"Solidity");
        skillshare::add_skill(charlie, b"Web3");
        
        // Create learning circle: Alice teaches Bob, Bob teaches Charlie, Charlie teaches Alice
        skillshare::request_teach(bob, signer::address_of(alice), b"Python");      // Request ID: 1
        skillshare::request_teach(charlie, signer::address_of(bob), b"React");     // Request ID: 2
        skillshare::request_teach(alice, signer::address_of(charlie), b"Solidity"); // Request ID: 3
        
        // Everyone accepts
        skillshare::accept_request(alice, 1);
        skillshare::accept_request(bob, 2);
        skillshare::accept_request(charlie, 3);
        
        // Fund all learners
        test_helpers::setup_coin_balance(alice, 200000000);
        test_helpers::setup_coin_balance(bob, 200000000);
        test_helpers::setup_coin_balance(charlie, 200000000);
        
        // All payments
        skillshare::deposit_payment(bob, 1);
        skillshare::deposit_payment(charlie, 2);
        skillshare::deposit_payment(alice, 3);
        
        // All acknowledgments
        skillshare::acknowledge_payment(alice, 1);
        skillshare::acknowledge_payment(bob, 2);
        skillshare::acknowledge_payment(charlie, 3);
        
        // Verify cross-contact access
        let bob_to_alice_contact = skillshare::get_contact_info(1, signer::address_of(bob));
        let charlie_to_bob_contact = skillshare::get_contact_info(2, signer::address_of(charlie));
        let alice_to_charlie_contact = skillshare::get_contact_info(3, signer::address_of(alice));
        
        assert!(!vector::is_empty(&bob_to_alice_contact), 316);
        assert!(!vector::is_empty(&charlie_to_bob_contact), 317);
        assert!(!vector::is_empty(&alice_to_charlie_contact), 318);
        
        // All communications start
        skillshare::learner_mark_communication_started(bob, 1);
        skillshare::learner_mark_communication_started(charlie, 2);
        skillshare::learner_mark_communication_started(alice, 3);
        
        // All lessons complete
        skillshare::teacher_request_release(alice, 1);
        skillshare::teacher_request_release(bob, 2);
        skillshare::teacher_request_release(charlie, 3);
        
        skillshare::learner_confirm_completion(bob, admin, 1);
        skillshare::learner_confirm_completion(charlie, admin, 2);
        skillshare::learner_confirm_completion(alice, admin, 3);
        
        // Final verification: Everyone both paid and earned 1 APT
        // Net effect: each user should have the same balance (minus gas)
        test_helpers::assert_balance_at_least(signer::address_of(alice), 95000000); // ~1 APT minus gas
        test_helpers::assert_balance_at_least(signer::address_of(bob), 95000000);
        test_helpers::assert_balance_at_least(signer::address_of(charlie), 95000000);
    }
}
