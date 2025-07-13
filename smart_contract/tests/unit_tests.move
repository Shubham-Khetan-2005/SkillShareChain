#[test_only]
module skillshare_addr::unit_tests {
    use skillshare_addr::skillshare;
    use skillshare_addr::test_helpers;
    use std::vector;
    use aptos_framework::coin;
    use aptos_framework::aptos_coin::AptosCoin;
    use std::signer;
    use aptos_framework::timestamp;

    // ==================== REGISTRATION TESTING ====================

    #[test(admin = @skillshare_addr, alice = @0xa)]
    fun test_register_user_with_contact(admin: &signer, alice: &signer) {
        test_helpers::setup_test_environment(admin);
        let contact_info = b"Discord: alice#1234, Email: alice@skillshare.com";
        skillshare::register_user_with_contact(alice, b"Alice", contact_info);
        test_helpers::assert_user_registered(signer::address_of(alice));
    }

    #[test(admin = @skillshare_addr, alice = @0xa)]
    fun test_add_skill_after_registration(admin: &signer, alice: &signer) {
        test_helpers::setup_test_environment(admin);
        test_helpers::register_user_simple(alice, b"Alice", b"alice");
        skillshare::add_skill(alice, b"Solidity");
        skillshare::add_skill(alice, b"React");
        skillshare::add_skill(alice, b"Python");
        test_helpers::assert_user_registered(signer::address_of(alice));
    }

    // ==================== PAYMENT TESTING ====================

    #[test(admin = @skillshare_addr, alice = @0xa, bob = @0xb, framework = @aptos_framework)]
    fun test_deposit_payment_functionality(admin: &signer, alice: &signer, bob: &signer, framework: &signer) {
        timestamp::set_time_has_started_for_testing(framework);
        let request_id = test_helpers::setup_users_and_request(admin, alice, bob);
        test_helpers::setup_coin_balance(alice, 200000000);
        let alice_addr = signer::address_of(alice);
        let initial_balance = coin::balance<AptosCoin>(alice_addr);
        skillshare::deposit_payment(alice, request_id);
        let final_balance = coin::balance<AptosCoin>(alice_addr);
        assert!(initial_balance - final_balance == 100000000, 101);
    }

    #[test(admin = @skillshare_addr, alice = @0xa, bob = @0xb, framework = @aptos_framework)]
    fun test_acknowledge_payment_functionality(admin: &signer, alice: &signer, bob: &signer, framework: &signer) {
        timestamp::set_time_has_started_for_testing(framework);
        let request_id = test_helpers::setup_payment_flow(admin, alice, bob);
        skillshare::acknowledge_payment(bob, request_id);
        test_helpers::assert_contact_accessible(request_id, signer::address_of(bob));
        test_helpers::assert_contact_accessible(request_id, signer::address_of(alice));
    }

    // ==================== COMMUNICATION TESTING ====================

    #[test(admin = @skillshare_addr, alice = @0xa, bob = @0xb, framework = @aptos_framework)]
    fun test_learner_mark_communication_started(admin: &signer, alice: &signer, bob: &signer, framework: &signer) {
        timestamp::set_time_has_started_for_testing(framework);
        let request_id = test_helpers::setup_acknowledged_payment(admin, alice, bob);
        skillshare::learner_mark_communication_started(alice, request_id);
    }

    #[test(admin = @skillshare_addr, alice = @0xa, bob = @0xb, framework = @aptos_framework)]
    fun test_learner_report_non_response(admin: &signer, alice: &signer, bob: &signer, framework: &signer) {
        timestamp::set_time_has_started_for_testing(framework);
        let request_id = test_helpers::setup_acknowledged_payment(admin, alice, bob);
        test_helpers::advance_time_by_hours(25);
        skillshare::learner_report_non_response(alice, request_id);
    }

    // ==================== COMPLETION TESTING ====================

    #[test(admin = @skillshare_addr, alice = @0xa, bob = @0xb, framework = @aptos_framework)]
    fun test_teacher_request_release(admin: &signer, alice: &signer, bob: &signer, framework: &signer) {
        timestamp::set_time_has_started_for_testing(framework);
        let request_id = test_helpers::setup_communication_started(admin, alice, bob);
        skillshare::teacher_request_release(bob, request_id);
    }

    #[test(admin = @skillshare_addr, alice = @0xa, bob = @0xb, framework = @aptos_framework)]
    fun test_learner_confirm_completion(admin: &signer, alice: &signer, bob: &signer, framework: &signer) {
        timestamp::set_time_has_started_for_testing(framework);
        let request_id = test_helpers::setup_lesson_completion_ready(admin, alice, bob);
        let bob_addr = signer::address_of(bob);
        let initial_balance = coin::balance<AptosCoin>(bob_addr);
        skillshare::learner_confirm_completion(alice, admin, request_id);
        let final_balance = coin::balance<AptosCoin>(bob_addr);
        assert!(final_balance - initial_balance == 100000000, 102);
    }

    #[test(admin = @skillshare_addr, alice = @0xa, bob = @0xb, framework = @aptos_framework)]
    fun test_claim_refund_functionality(admin: &signer, alice: &signer, bob: &signer, framework: &signer) {
        timestamp::set_time_has_started_for_testing(framework);
        let request_id = test_helpers::setup_non_response_scenario(admin, alice, bob);
        let alice_addr = signer::address_of(alice);
        let initial_balance = coin::balance<AptosCoin>(alice_addr);
        skillshare::learner_report_non_response(alice, request_id);
        skillshare::claim_refund(alice, admin, request_id);
        let final_balance = coin::balance<AptosCoin>(alice_addr);
        assert!(final_balance - initial_balance == 100000000, 103);
    }

    // ==================== VIEW FUNCTION TESTING ====================

    #[test(admin = @skillshare_addr, alice = @0xa, bob = @0xb, framework = @aptos_framework)]
    fun test_get_contact_info_view(admin: &signer, alice: &signer, bob: &signer, framework: &signer) {
        timestamp::set_time_has_started_for_testing(framework);
        let request_id = test_helpers::setup_acknowledged_payment(admin, alice, bob);
        let learner_contact = skillshare::get_contact_info(request_id, signer::address_of(bob));
        assert!(!vector::is_empty(&learner_contact), 104);
        assert!(vector::length(&learner_contact) > 10, 105);
        let teacher_contact = skillshare::get_contact_info(request_id, signer::address_of(alice));
        assert!(!vector::is_empty(&teacher_contact), 106);
        assert!(vector::length(&teacher_contact) > 10, 107);
    }

    #[test(admin = @skillshare_addr, alice = @0xa)]
    fun test_user_exists_view_function(admin: &signer, alice: &signer) {
        test_helpers::setup_test_environment(admin);
        let alice_addr = signer::address_of(alice);
        assert!(!skillshare::user_exists(alice_addr), 108);
        test_helpers::register_user_simple(alice, b"Alice", b"alice");
        assert!(skillshare::user_exists(alice_addr), 109);
    }

    // ==================== INITIALIZATION TESTING ====================

    #[test(admin = @skillshare_addr)]
    fun test_platform_config_initialization(admin: &signer) {
        test_helpers::setup_test_environment(admin);
        // Add view assertions for config if needed
    }
}
