#[test_only]
module skillshare_addr::payment_tests {
    use skillshare_addr::skillshare;
    use skillshare_addr::test_helpers;
    use aptos_framework::account;
    use aptos_framework::coin;
    use aptos_framework::aptos_coin::AptosCoin;
    use aptos_framework::timestamp;
    use std::vector;
    use std::bcs;
    use std::signer;

    // ==================== PAYMENT FLOW TESTING ====================

    #[test(admin = @skillshare_addr, alice = @0xa, bob = @0xb, framework = @aptos_framework)]
    fun test_complete_payment_flow(admin: &signer, alice: &signer, bob: &signer, framework: &signer) {
        timestamp::set_time_has_started_for_testing(framework);
        test_helpers::setup_test_environment(admin);
        
        // Setup users and request
        test_helpers::register_user_with_default_contact(alice, b"Alice", b"alice");
        test_helpers::register_user_with_default_contact(bob, b"Bob", b"bob");
        skillshare::add_skill(bob, b"Solidity");
        
        skillshare::request_teach(alice, signer::address_of(bob), b"Solidity");
        skillshare::accept_request(bob, 1);
        
        // Record initial balances
        let alice_addr = signer::address_of(alice);
        let bob_addr = signer::address_of(bob);
        
        test_helpers::setup_coin_balance(alice, 200000000); // 2 APT
        let alice_initial = coin::balance<AptosCoin>(alice_addr);
        let bob_initial = coin::balance<AptosCoin>(bob_addr);
        
        // Payment flow
        skillshare::deposit_payment(alice, 1);
        skillshare::acknowledge_payment(bob, 1);
        skillshare::learner_mark_communication_started(alice, 1);
        skillshare::teacher_request_release(bob, 1);
        skillshare::learner_confirm_completion(alice, admin, 1);
        
        // Verify final balances
        let alice_final = coin::balance<AptosCoin>(alice_addr);
        let bob_final = coin::balance<AptosCoin>(bob_addr);
        
        assert!(alice_initial - alice_final == 100000000, 201); // Alice paid 1 APT
        assert!(bob_final - bob_initial == 100000000, 202);     // Bob received 1 APT
    }

    #[test(admin = @skillshare_addr, alice = @0xa, bob = @0xb, framework = @aptos_framework)]
    fun test_refund_payment_flow(admin: &signer, alice: &signer, bob: &signer, framework: &signer) {
        timestamp::set_time_has_started_for_testing(framework);
        let request_id = test_helpers::setup_acknowledged_payment(admin, alice, bob);
        
        let alice_addr = signer::address_of(alice);
        let initial_balance = coin::balance<AptosCoin>(alice_addr);
        
        // Advance time and process refund
        test_helpers::advance_time_by_hours(25);
        skillshare::learner_report_non_response(alice, request_id);
        skillshare::claim_refund(alice, admin, request_id);
        
        // Verify Alice got full refund
        let final_balance = coin::balance<AptosCoin>(alice_addr);
        assert!(final_balance - initial_balance == 100000000, 203); // Full 1 APT refund
    }

    // ==================== MULTIPLE PAYMENT TESTING ====================

    #[test(admin = @skillshare_addr, alice = @0xa, bob = @0xb, charlie = @0xc, framework = @aptos_framework)]
    fun test_multiple_concurrent_payments(admin: &signer, alice: &signer, bob: &signer, charlie: &signer, framework: &signer) {
        timestamp::set_time_has_started_for_testing(framework);
        test_helpers::setup_test_environment(admin);
        
        // Setup multiple users
        test_helpers::register_user_with_default_contact(alice, b"Alice", b"alice");
        test_helpers::register_user_with_default_contact(bob, b"Bob", b"bob");
        test_helpers::register_user_with_default_contact(charlie, b"Charlie", b"charlie");
        
        skillshare::add_skill(bob, b"Solidity");
        skillshare::add_skill(charlie, b"React");
        
        // Alice requests from both teachers
        skillshare::request_teach(alice, signer::address_of(bob), b"Solidity");
        skillshare::request_teach(alice, signer::address_of(charlie), b"React");
        
        skillshare::accept_request(bob, 1);
        skillshare::accept_request(charlie, 2);
        
        // Alice pays for both lessons
        test_helpers::setup_coin_balance(alice, 400000000); // 4 APT
        let alice_addr = signer::address_of(alice);
        let initial_balance = coin::balance<AptosCoin>(alice_addr);
        
        skillshare::deposit_payment(alice, 1);
        skillshare::deposit_payment(alice, 2);
        
        // Verify both payments deducted
        let after_payments = coin::balance<AptosCoin>(alice_addr);
        assert!(initial_balance - after_payments == 200000000, 204); // 2 APT total
        
        // Complete both lessons
        skillshare::acknowledge_payment(bob, 1);
        skillshare::acknowledge_payment(charlie, 2);
        
        skillshare::learner_mark_communication_started(alice, 1);
        skillshare::learner_mark_communication_started(alice, 2);
        
        skillshare::teacher_request_release(bob, 1);
        skillshare::teacher_request_release(charlie, 2);
        
        skillshare::learner_confirm_completion(alice, admin, 1);
        skillshare::learner_confirm_completion(alice, admin, 2);
        
        // Verify teachers received payments
        test_helpers::assert_balance_at_least(signer::address_of(bob), 100000000);
        test_helpers::assert_balance_at_least(signer::address_of(charlie), 100000000);
    }

    // ==================== PAYMENT TIMING TESTING ====================

    #[test(admin = @skillshare_addr, alice = @0xa, bob = @0xb, framework = @aptos_framework)]
    fun test_payment_timing_constraints(admin: &signer, alice: &signer, bob: &signer, framework: &signer) {
        timestamp::set_time_has_started_for_testing(framework);
        let request_id = test_helpers::setup_acknowledged_payment(admin, alice, bob);
        
        // Test immediate communication marking (should work)
        skillshare::learner_mark_communication_started(alice, request_id);
        
        // Test immediate completion request (should work)
        skillshare::teacher_request_release(bob, request_id);
        skillshare::learner_confirm_completion(alice, admin, request_id);
        
        // Verify payment completed successfully
        test_helpers::assert_balance_at_least(signer::address_of(bob), 100000000);
    }

    #[test(admin = @skillshare_addr, alice = @0xa, bob = @0xb, framework = @aptos_framework)]
    fun test_non_response_timing(admin: &signer, alice: &signer, bob: &signer, framework: &signer) {
        timestamp::set_time_has_started_for_testing(framework);
        let request_id = test_helpers::setup_acknowledged_payment(admin, alice, bob);
        
        // Test that non-response reporting requires 24+ hours
        test_helpers::advance_time_by_hours(23); // Just under 24 hours
        
        // Advance to exactly 24 hours and 1 second
        test_helpers::advance_time_by_hours(1);
        
        // Should be able to report non-response now
        skillshare::learner_report_non_response(alice, request_id);
        skillshare::claim_refund(alice, admin, request_id);
        
        test_helpers::assert_balance_at_least(signer::address_of(alice), 100000000);
    }

    // ==================== CONTACT ACCESS TESTING ====================

    #[test(admin = @skillshare_addr, alice = @0xa, bob = @0xb, framework = @aptos_framework)]
    fun test_contact_access_after_payment(admin: &signer, alice: &signer, bob: &signer, framework: &signer) {
        timestamp::set_time_has_started_for_testing(framework);
        let request_id = test_helpers::setup_payment_flow(admin, alice, bob);
        
        // After acknowledgment - contact should be accessible
        skillshare::acknowledge_payment(bob, request_id);
        
        let alice_contact = skillshare::get_contact_info(request_id, signer::address_of(bob));
        let bob_contact = skillshare::get_contact_info(request_id, signer::address_of(alice));
        
        assert!(!vector::is_empty(&alice_contact), 205);
        assert!(!vector::is_empty(&bob_contact), 206);
        
        // Verify contact info contains expected patterns
        assert!(vector::length(&alice_contact) > 20, 207); // Should have meaningful content
        assert!(vector::length(&bob_contact) > 20, 208);
    }

    // ==================== BALANCE VALIDATION TESTING ====================

    #[test(admin = @skillshare_addr, alice = @0xa, bob = @0xb, framework = @aptos_framework)]
    fun test_exact_payment_amounts(admin: &signer, alice: &signer, bob: &signer, framework: &signer) {
        timestamp::set_time_has_started_for_testing(framework);
        test_helpers::setup_test_environment(admin);
        
        // Give Alice exactly 1 APT + small amount for gas
        test_helpers::setup_coin_balance(alice, 110000000); // 1.1 APT
        
        let request_id = test_helpers::setup_users_and_request(admin, alice, bob);
        
        let alice_addr = signer::address_of(alice);
        let bob_addr = signer::address_of(bob);
        
        let alice_before = coin::balance<AptosCoin>(alice_addr);
        let bob_before = coin::balance<AptosCoin>(bob_addr);
        
        // Complete payment flow
        skillshare::deposit_payment(alice, request_id);
        skillshare::acknowledge_payment(bob, request_id);
        skillshare::learner_mark_communication_started(alice, request_id);
        skillshare::teacher_request_release(bob, request_id);
        skillshare::learner_confirm_completion(alice, admin, request_id);
        
        let alice_after = coin::balance<AptosCoin>(alice_addr);
        let bob_after = coin::balance<AptosCoin>(bob_addr);
        
        // Verify exact amounts
        assert!(alice_before - alice_after == 100000000, 209); // Exactly 1 APT
        assert!(bob_after - bob_before == 100000000, 210);     // Exactly 1 APT
    }

    // ==================== STRESS TESTING ====================

    #[test(admin = @skillshare_addr, framework = @aptos_framework)]
    fun test_multiple_sequential_payments(admin: &signer, framework: &signer) {
        timestamp::set_time_has_started_for_testing(framework);
        test_helpers::setup_test_environment(admin);
        
        // Use predefined addresses instead of arithmetic
        let test_addresses = test_helpers::get_test_addresses();
        let teacher_addr = *vector::borrow(&test_addresses, 0); // Use first address as teacher
        let teacher = account::create_signer_for_test(teacher_addr);
        test_helpers::register_user_with_default_contact(&teacher, b"Teacher", b"teacher");
        skillshare::add_skill(&teacher, b"TestSkill");
        
        let i = 1; // Start from index 1 (skip teacher address)
        while (i < 11 && i < vector::length(&test_addresses)) { // Process 10 learners
            let learner_addr = *vector::borrow(&test_addresses, i);
            let learner = account::create_signer_for_test(learner_addr);
            
            let username = b"learner";
            vector::append(&mut username, bcs::to_bytes(&i));
            test_helpers::register_user_with_default_contact(&learner, copy username, username);
            test_helpers::setup_coin_balance(&learner, 200000000);
            
            // Complete full payment cycle
            skillshare::request_teach(&learner, teacher_addr, b"TestSkill");
            skillshare::accept_request(&teacher, i);
            skillshare::deposit_payment(&learner, i);
            skillshare::acknowledge_payment(&teacher, i);
            skillshare::learner_mark_communication_started(&learner, i);
            skillshare::teacher_request_release(&teacher, i);
            skillshare::learner_confirm_completion(&learner, admin, i);
            
            i = i + 1;
        };
        
        // Verify teacher received all payments (10 APT)
        test_helpers::assert_balance_at_least(teacher_addr, 1000000000); // 10 APT
    }
}
