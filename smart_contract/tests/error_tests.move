#[test_only]
module skillshare_addr::error_tests {
    use skillshare_addr::skillshare;
    use skillshare_addr::test_helpers;
    use aptos_framework::timestamp;
    use std::vector;
    use std::signer;

    // ==================== REGISTRATION ERROR TESTS ====================

    #[test(admin = @skillshare_addr, alice = @0xa)]
    #[expected_failure(abort_code = 1, location = skillshare_addr::skillshare)]
    fun test_duplicate_registration_error(admin: &signer, alice: &signer) {
        test_helpers::setup_test_environment(admin);
        
        // First registration should succeed
        skillshare::register_user_with_contact(alice, b"Alice", b"alice@example.com");
        
        // Second registration should fail with error code 1
        skillshare::register_user_with_contact(alice, b"Alice", b"alice@example.com");
    }

    #[test(admin = @skillshare_addr, alice = @0xa)]
    #[expected_failure(abort_code = 7, location = skillshare_addr::skillshare)]
    fun test_empty_contact_info_error(admin: &signer, alice: &signer) {
        test_helpers::setup_test_environment(admin);
        
        // Empty contact info should fail with error code 7
        skillshare::register_user_with_contact(alice, b"Alice", b"");
    }

    #[test(admin = @skillshare_addr, alice = @0xa)]
    #[expected_failure(abort_code = 8, location = skillshare_addr::skillshare)]
    fun test_contact_info_too_long_error(admin: &signer, alice: &signer) {
        test_helpers::setup_test_environment(admin);
        
        // Create contact info longer than 500 characters
        let long_contact = b"Discord: verylongusername#1234, Email: verylongusername@example.com, ";
        let i = 0;
        while (i < 10) {
            let additional = b"This is additional text to make the contact info very long and exceed the 500 character limit. ";
            vector::append(&mut long_contact, additional);
            i = i + 1;
        };
        
        // Should fail with error code 8
        skillshare::register_user_with_contact(alice, b"Alice", long_contact);
    }

    #[test(admin = @skillshare_addr, alice = @0xa)]
    #[expected_failure(abort_code = 2, location = skillshare_addr::skillshare)]
    fun test_add_skill_without_registration_error(admin: &signer, alice: &signer) {
        test_helpers::setup_test_environment(admin);
        
        // Try to add skill without registering first - should fail with error code 2
        skillshare::add_skill(alice, b"React");
    }

    // ==================== REQUEST ERROR TESTS ====================

    #[test(admin = @skillshare_addr, alice = @0xa)]
    #[expected_failure(abort_code = 3, location = skillshare_addr::skillshare)]
    fun test_request_from_non_existent_teacher_error(admin: &signer, alice: &signer) {
        test_helpers::setup_test_environment(admin);
        
        // Register learner but not teacher
        test_helpers::register_user_simple(alice, b"Alice", b"alice");
        
        // Request from non-existent teacher should fail with error code 3
        skillshare::request_teach(alice, @0xdead, b"React");
    }

    #[test(admin = @skillshare_addr, alice = @0xa, bob = @0xb)]
    #[expected_failure(abort_code = 4, location = skillshare_addr::skillshare)]
    fun test_accept_non_existent_request_error(admin: &signer, alice: &signer, bob: &signer) {
        test_helpers::setup_test_environment(admin);
        
        test_helpers::register_user_simple(alice, b"Alice", b"alice");
        test_helpers::register_user_simple(bob, b"Bob", b"bob");
        
        // Try to accept non-existent request - should fail with error code 4
        skillshare::accept_request(bob, 999);
    }

    #[test(admin = @skillshare_addr, alice = @0xa, bob = @0xb, charlie = @0xc)]
    #[expected_failure(abort_code = 5, location = skillshare_addr::skillshare)]
    fun test_accept_wrong_teacher_request_error(admin: &signer, alice: &signer, bob: &signer, charlie: &signer) {
        test_helpers::setup_test_environment(admin);
        
        test_helpers::register_user_simple(alice, b"Alice", b"alice");
        test_helpers::register_user_simple(bob, b"Bob", b"bob");
        test_helpers::register_user_simple(charlie, b"Charlie", b"charlie");
        
        skillshare::add_skill(bob, b"React");
        
        // Alice requests from Bob
        skillshare::request_teach(alice, signer::address_of(bob), b"React");
        
        // Charlie tries to accept Bob's request - should fail with error code 5
        skillshare::accept_request(charlie, 1);
    }

    #[test(admin = @skillshare_addr, alice = @0xa, bob = @0xb)]
    #[expected_failure(abort_code = 6, location = skillshare_addr::skillshare)]
    fun test_reject_already_accepted_request_error(admin: &signer, alice: &signer, bob: &signer) {
        test_helpers::setup_test_environment(admin);
        
        test_helpers::register_user_simple(alice, b"Alice", b"alice");
        test_helpers::register_user_simple(bob, b"Bob", b"bob");
        skillshare::add_skill(bob, b"React");
        
        skillshare::request_teach(alice, signer::address_of(bob), b"React");
        skillshare::accept_request(bob, 1);
        
        // Try to reject already accepted request - should fail with error code 6
        skillshare::reject_request(bob, 1);
    }

    // ==================== PAYMENT ERROR TESTS ====================

    #[test(admin = @skillshare_addr, alice = @0xa, bob = @0xb, framework = @aptos_framework)]
    #[expected_failure(abort_code = 10, location = skillshare_addr::skillshare)]
    fun test_insufficient_balance_error(admin: &signer, alice: &signer, bob: &signer, framework: &signer) {
        timestamp::set_time_has_started_for_testing(framework);
        let request_id = test_helpers::setup_users_and_request(admin, alice, bob);
        
        // Give Alice insufficient balance (0.5 APT)
        test_helpers::setup_coin_balance(alice, 50000000);
        
        // Try to deposit 1 APT with insufficient balance - should fail with error code 10
        skillshare::deposit_payment(alice, request_id);
    }

    #[test(admin = @skillshare_addr, alice = @0xa, bob = @0xb, framework = @aptos_framework)]
    #[expected_failure(abort_code = 9, location = skillshare_addr::skillshare)]
    fun test_double_payment_error(admin: &signer, alice: &signer, bob: &signer, framework: &signer) {
        timestamp::set_time_has_started_for_testing(framework);
        let request_id = test_helpers::setup_users_and_request(admin, alice, bob);
        
        test_helpers::setup_coin_balance(alice, 400000000); // 4 APT
        
        // First payment should succeed
        skillshare::deposit_payment(alice, request_id);
        
        // Second payment should fail with error code 9
        skillshare::deposit_payment(alice, request_id);
    }

    #[test(admin = @skillshare_addr, alice = @0xa, bob = @0xb, framework = @aptos_framework)]
    #[expected_failure(abort_code = 11, location = skillshare_addr::skillshare)]
    fun test_payment_without_acceptance_error(admin: &signer, alice: &signer, bob: &signer, framework: &signer) {
        timestamp::set_time_has_started_for_testing(framework);
        test_helpers::setup_test_environment(admin);
        
        test_helpers::register_user_with_default_contact(alice, b"Alice", b"alice");
        test_helpers::register_user_with_default_contact(bob, b"Bob", b"bob");
        skillshare::add_skill(bob, b"React");
        
        // Create request but don't accept it
        skillshare::request_teach(alice, signer::address_of(bob), b"React");
        
        test_helpers::setup_coin_balance(alice, 200000000);
        
        // Try to pay without acceptance - should fail with error code 11
        skillshare::deposit_payment(alice, 1);
    }

    #[test(admin = @skillshare_addr, alice = @0xa, bob = @0xb, charlie = @0xc, framework = @aptos_framework)]
    #[expected_failure(abort_code = 5, location = skillshare_addr::skillshare)]
    fun test_payment_wrong_learner_error(admin: &signer, alice: &signer, bob: &signer, charlie: &signer, framework: &signer) {
        timestamp::set_time_has_started_for_testing(framework);
        let request_id = test_helpers::setup_users_and_request(admin, alice, bob);
        
        test_helpers::register_user_with_default_contact(charlie, b"Charlie", b"charlie");
        test_helpers::setup_coin_balance(charlie, 200000000);
        
        // Charlie tries to pay for Alice's request - should fail with error code 5
        skillshare::deposit_payment(charlie, request_id);
    }

    // ==================== ACKNOWLEDGMENT ERROR TESTS ====================

    #[test(admin = @skillshare_addr, alice = @0xa, bob = @0xb, framework = @aptos_framework)]
    #[expected_failure(abort_code = 12, location = skillshare_addr::skillshare)]
    fun test_acknowledge_without_payment_error(admin: &signer, alice: &signer, bob: &signer, framework: &signer) {
        timestamp::set_time_has_started_for_testing(framework);
        let request_id = test_helpers::setup_users_and_request(admin, alice, bob);
        
        // Try to acknowledge without payment - should fail with error code 12
        skillshare::acknowledge_payment(bob, request_id);
    }

    #[test(admin = @skillshare_addr, alice = @0xa, bob = @0xb, framework = @aptos_framework)]
    #[expected_failure(abort_code = 13, location = skillshare_addr::skillshare)]
    fun test_double_acknowledgment_error(admin: &signer, alice: &signer, bob: &signer, framework: &signer) {
        timestamp::set_time_has_started_for_testing(framework);
        let request_id = test_helpers::setup_payment_flow(admin, alice, bob);
        
        // First acknowledgment should succeed
        skillshare::acknowledge_payment(bob, request_id);
        
        // Second acknowledgment should fail with error code 13
        skillshare::acknowledge_payment(bob, request_id);
    }

    #[test(admin = @skillshare_addr, alice = @0xa, bob = @0xb, charlie = @0xc, framework = @aptos_framework)]
    #[expected_failure(abort_code = 5, location = skillshare_addr::skillshare)]
    fun test_acknowledge_wrong_teacher_error(admin: &signer, alice: &signer, bob: &signer, charlie: &signer, framework: &signer) {
        timestamp::set_time_has_started_for_testing(framework);
        let request_id = test_helpers::setup_payment_flow(admin, alice, bob);
        
        test_helpers::register_user_with_default_contact(charlie, b"Charlie", b"charlie");
        
        // Charlie tries to acknowledge Bob's request - should fail with error code 5
        skillshare::acknowledge_payment(charlie, request_id);
    }

    // ==================== CONTACT ACCESS ERROR TESTS ====================

    #[test(admin = @skillshare_addr, alice = @0xa, bob = @0xb, charlie = @0xc, framework = @aptos_framework)]
    #[expected_failure(abort_code = 14, location = skillshare_addr::skillshare)]
    fun test_unauthorized_contact_access_error(admin: &signer, alice: &signer, bob: &signer, charlie: &signer, framework: &signer) {
        timestamp::set_time_has_started_for_testing(framework);
        let request_id = test_helpers::setup_acknowledged_payment(admin, alice, bob);
        
        test_helpers::register_user_with_default_contact(charlie, b"Charlie", b"charlie");
        
        // Charlie tries to access contact info for Alice-Bob request - should fail with error code 14
        skillshare::get_contact_info(request_id, signer::address_of(charlie));
    }

    #[test(admin = @skillshare_addr, alice = @0xa, bob = @0xb, framework = @aptos_framework)]
    #[expected_failure(abort_code = 14, location = skillshare_addr::skillshare)]
    fun test_contact_access_before_acknowledgment_error(admin: &signer, alice: &signer, bob: &signer, framework: &signer) {
        timestamp::set_time_has_started_for_testing(framework);
        let request_id = test_helpers::setup_payment_flow(admin, alice, bob);
        
        // Try to access contact before acknowledgment - should fail with error code 14
        skillshare::get_contact_info(request_id, signer::address_of(bob));
    }

    // ==================== COMMUNICATION ERROR TESTS ====================

    #[test(admin = @skillshare_addr, alice = @0xa, bob = @0xb, framework = @aptos_framework)]
    #[expected_failure(abort_code = 14, location = skillshare_addr::skillshare)]
    fun test_communication_start_without_acknowledgment_error(admin: &signer, alice: &signer, bob: &signer, framework: &signer) {
        timestamp::set_time_has_started_for_testing(framework);
        let request_id = test_helpers::setup_payment_flow(admin, alice, bob);
        
        // Try to mark communication started without acknowledgment - should fail with error code 14
        skillshare::learner_mark_communication_started(alice, request_id);
    }

    #[test(admin = @skillshare_addr, alice = @0xa, bob = @0xb, framework = @aptos_framework)]
    #[expected_failure(abort_code = 15, location = skillshare_addr::skillshare)]
    fun test_double_communication_start_error(admin: &signer, alice: &signer, bob: &signer, framework: &signer) {
        timestamp::set_time_has_started_for_testing(framework);
        let request_id = test_helpers::setup_acknowledged_payment(admin, alice, bob);
        
        // First communication start should succeed
        skillshare::learner_mark_communication_started(alice, request_id);
        
        // Second communication start should fail with error code 15
        skillshare::learner_mark_communication_started(alice, request_id);
    }

    #[test(admin = @skillshare_addr, alice = @0xa, bob = @0xb, charlie = @0xc, framework = @aptos_framework)]
    #[expected_failure(abort_code = 5, location = skillshare_addr::skillshare)]
    fun test_wrong_learner_communication_start_error(admin: &signer, alice: &signer, bob: &signer, charlie: &signer, framework: &signer) {
        timestamp::set_time_has_started_for_testing(framework);
        let request_id = test_helpers::setup_acknowledged_payment(admin, alice, bob);
        
        test_helpers::register_user_with_default_contact(charlie, b"Charlie", b"charlie");
        
        // Charlie tries to mark communication started for Alice's request - should fail with error code 5
        skillshare::learner_mark_communication_started(charlie, request_id);
    }

    // ==================== NON-RESPONSE ERROR TESTS ====================

    #[test(admin = @skillshare_addr, alice = @0xa, bob = @0xb, framework = @aptos_framework)]
    #[expected_failure(abort_code = 16, location = skillshare_addr::skillshare)]
    fun test_non_response_after_communication_started_error(admin: &signer, alice: &signer, bob: &signer, framework: &signer) {
        timestamp::set_time_has_started_for_testing(framework);
        let request_id = test_helpers::setup_acknowledged_payment(admin, alice, bob);
        
        // Communication started
        skillshare::learner_mark_communication_started(alice, request_id);
        
        test_helpers::advance_time_by_hours(25);
        
        // Try to report non-response after communication started - should fail with error code 16
        skillshare::learner_report_non_response(alice, request_id);
    }

    #[test(admin = @skillshare_addr, alice = @0xa, bob = @0xb, framework = @aptos_framework)]
    #[expected_failure(abort_code = 17, location = skillshare_addr::skillshare)]
    fun test_non_response_too_early_error(admin: &signer, alice: &signer, bob: &signer, framework: &signer) {
        timestamp::set_time_has_started_for_testing(framework);
        let request_id = test_helpers::setup_acknowledged_payment(admin, alice, bob);
        
        // Only advance 12 hours (less than required 24 hours)
        test_helpers::advance_time_by_hours(12);
        
        // Try to report non-response too early - should fail with error code 17
        skillshare::learner_report_non_response(alice, request_id);
    }

    // ==================== COMPLETION ERROR TESTS ====================

    #[test(admin = @skillshare_addr, alice = @0xa, bob = @0xb, framework = @aptos_framework)]
    #[expected_failure(abort_code = 16, location = skillshare_addr::skillshare)]
    fun test_teacher_release_without_communication_error(admin: &signer, alice: &signer, bob: &signer, framework: &signer) {
        timestamp::set_time_has_started_for_testing(framework);
        let request_id = test_helpers::setup_acknowledged_payment(admin, alice, bob);
        
        // Try to request release without communication started - should fail with error code 16
        skillshare::teacher_request_release(bob, request_id);
    }

    #[test(admin = @skillshare_addr, alice = @0xa, bob = @0xb, framework = @aptos_framework)]
    #[expected_failure(abort_code = 18, location = skillshare_addr::skillshare)]
    fun test_double_teacher_release_request_error(admin: &signer, alice: &signer, bob: &signer, framework: &signer) {
        timestamp::set_time_has_started_for_testing(framework);
        let request_id = test_helpers::setup_communication_started(admin, alice, bob);
        
        // First release request should succeed
        skillshare::teacher_request_release(bob, request_id);
        
        // Second release request should fail with error code 18
        skillshare::teacher_request_release(bob, request_id);
    }

    #[test(admin = @skillshare_addr, alice = @0xa, bob = @0xb, framework = @aptos_framework)]
    #[expected_failure(abort_code = 19, location = skillshare_addr::skillshare)]
    fun test_learner_confirm_without_teacher_request_error(admin: &signer, alice: &signer, bob: &signer, framework: &signer) {
        timestamp::set_time_has_started_for_testing(framework);
        let request_id = test_helpers::setup_communication_started(admin, alice, bob);
        
        // Try to confirm completion without teacher request - should fail with error code 19
        skillshare::learner_confirm_completion(alice, admin, request_id);
    }

    #[test(admin = @skillshare_addr, alice = @0xa, bob = @0xb, framework = @aptos_framework)]
    #[expected_failure(abort_code = 20, location = skillshare_addr::skillshare)]
    fun test_double_payment_release_error(admin: &signer, alice: &signer, bob: &signer, framework: &signer) {
        timestamp::set_time_has_started_for_testing(framework);
        let request_id = test_helpers::setup_lesson_completion_ready(admin, alice, bob);
        
        // First confirmation should succeed
        skillshare::learner_confirm_completion(alice, admin, request_id);
        
        // Second confirmation should fail with error code 20
        skillshare::learner_confirm_completion(alice, admin, request_id);
    }

    // ==================== REFUND ERROR TESTS ====================

    #[test(admin = @skillshare_addr, alice = @0xa, bob = @0xb, framework = @aptos_framework)]
    #[expected_failure(abort_code = 21, location = skillshare_addr::skillshare)]
    fun test_refund_without_non_response_report_error(admin: &signer, alice: &signer, bob: &signer, framework: &signer) {
        timestamp::set_time_has_started_for_testing(framework);
        let request_id = test_helpers::setup_acknowledged_payment(admin, alice, bob);
        
        test_helpers::advance_time_by_hours(25);
        
        // Try to claim refund without reporting non-response - should fail with error code 21
        skillshare::claim_refund(alice, admin, request_id);
    }

    #[test(admin = @skillshare_addr, alice = @0xa, bob = @0xb, framework = @aptos_framework)]
    #[expected_failure(abort_code = 22, location = skillshare_addr::skillshare)]
    fun test_double_refund_error(admin: &signer, alice: &signer, bob: &signer, framework: &signer) {
        timestamp::set_time_has_started_for_testing(framework);
        let request_id = test_helpers::setup_acknowledged_payment(admin, alice, bob);
        
        test_helpers::advance_time_by_hours(25);
        skillshare::learner_report_non_response(alice, request_id);
        
        // First refund should succeed
        skillshare::claim_refund(alice, admin, request_id);
        
        // Second refund should fail with error code 22
        skillshare::claim_refund(alice, admin, request_id);
    }

    #[test(admin = @skillshare_addr, alice = @0xa, bob = @0xb, charlie = @0xc, framework = @aptos_framework)]
    #[expected_failure(abort_code = 5, location = skillshare_addr::skillshare)]
    fun test_wrong_learner_refund_error(admin: &signer, alice: &signer, bob: &signer, charlie: &signer, framework: &signer) {
        timestamp::set_time_has_started_for_testing(framework);
        let request_id = test_helpers::setup_acknowledged_payment(admin, alice, bob);
        
        test_helpers::register_user_with_default_contact(charlie, b"Charlie", b"charlie");
        
        test_helpers::advance_time_by_hours(25);
        skillshare::learner_report_non_response(alice, request_id);
        
        // Charlie tries to claim Alice's refund - should fail with error code 5
        skillshare::claim_refund(charlie, admin, request_id);
    }

    // ==================== BOUNDARY CONDITION TESTS ====================

    #[test(admin = @skillshare_addr, alice = @0xa, bob = @0xb, framework = @aptos_framework)]
    fun test_non_response_exactly_24_hours_success(admin: &signer, alice: &signer, bob: &signer, framework: &signer) {
        timestamp::set_time_has_started_for_testing(framework);
        let request_id = test_helpers::setup_acknowledged_payment(admin, alice, bob);
        
        // Advance exactly 24 hours (should succeed)
        test_helpers::advance_time_by_hours(24);
        
        // Should succeed - 24 hours is the threshold
        skillshare::learner_report_non_response(alice, request_id);
    }

    // ==================== INVALID STATE TRANSITION TESTS ====================

    #[test(admin = @skillshare_addr, alice = @0xa, bob = @0xb, framework = @aptos_framework)]
    #[expected_failure(abort_code = 11, location = skillshare_addr::skillshare)]
    fun test_payment_on_rejected_request_error(admin: &signer, alice: &signer, bob: &signer, framework: &signer) {
        timestamp::set_time_has_started_for_testing(framework);
        test_helpers::setup_test_environment(admin);
        
        test_helpers::register_user_with_default_contact(alice, b"Alice", b"alice");
        test_helpers::register_user_with_default_contact(bob, b"Bob", b"bob");
        skillshare::add_skill(bob, b"React");
        
        skillshare::request_teach(alice, signer::address_of(bob), b"React");
        skillshare::reject_request(bob, 1);
        
        test_helpers::setup_coin_balance(alice, 200000000);
        
        // Try to pay for rejected request - should fail with error code 11
        skillshare::deposit_payment(alice, 1);
    }

    #[test(admin = @skillshare_addr, alice = @0xa, bob = @0xb, charlie = @0xc, framework = @aptos_framework)]
    #[expected_failure(abort_code = 5, location = skillshare_addr::skillshare)]
    fun test_wrong_teacher_release_request_error(admin: &signer, alice: &signer, bob: &signer, charlie: &signer, framework: &signer) {
        timestamp::set_time_has_started_for_testing(framework);
        let request_id = test_helpers::setup_communication_started(admin, alice, bob);
        
        test_helpers::register_user_with_default_contact(charlie, b"Charlie", b"charlie");
        
        // Charlie tries to request release for Bob's lesson - should fail with error code 5
        skillshare::teacher_request_release(charlie, request_id);
    }

    #[test(admin = @skillshare_addr, alice = @0xa, bob = @0xb, charlie = @0xc, framework = @aptos_framework)]
    #[expected_failure(abort_code = 5, location = skillshare_addr::skillshare)]
    fun test_wrong_learner_confirm_completion_error(admin: &signer, alice: &signer, bob: &signer, charlie: &signer, framework: &signer) {
        timestamp::set_time_has_started_for_testing(framework);
        let request_id = test_helpers::setup_lesson_completion_ready(admin, alice, bob);
        
        test_helpers::register_user_with_default_contact(charlie, b"Charlie", b"charlie");
        
        // Charlie tries to confirm completion for Alice's lesson - should fail with error code 5
        skillshare::learner_confirm_completion(charlie, admin, request_id);
    }
}
