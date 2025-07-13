module 0x2::basic {
    use skillshare_addr::skillshare;
    use aptos_framework::account;
    use std::signer;

    #[test(alice = @0xa, admin = @skillshare_addr)]
    fun it_registers(admin: &signer, alice: signer) {
        account::create_account_for_test(signer::address_of(admin));
        skillshare::init_registration_events(admin);
        skillshare::register_user(&alice, b"alice");
        skillshare::add_skill(&alice, b"solidity");
    }
    


    #[test]
    fun it_returns_false_if_not_registered() {
        let _tmp = account::create_signer_for_test(@0xAAA);
        assert!(!skillshare::user_exists(@0xAAA), 101);
    }

    #[test(admin = @skillshare_addr, alice = @0xa, bob = @0xb)]
    fun test_request_flow(admin: &signer, alice: &signer, bob: &signer) {
        account::create_account_for_test(signer::address_of(admin));
        skillshare::init_registration_events(admin);
        skillshare::init_global_requests(admin);

        skillshare::register_user(alice, b"Alice");
        skillshare::register_user(bob, b"Bob");
        skillshare::add_skill(alice, b"React");
        skillshare::add_skill(bob, b"Move");
    }

    #[test(admin = @skillshare_addr, alice = @0xa, bob = @0xb)]
    fun test_request_and_accept_flow(admin: &signer, alice: &signer, bob: &signer) {
        account::create_account_for_test(signer::address_of(admin));
        skillshare::init_registration_events(admin);
        skillshare::init_global_requests(admin);

        skillshare::register_user(alice, b"Alice");
        skillshare::register_user(bob, b"Bob");
        skillshare::add_skill(bob, b"Solidity");

        skillshare::request_teach(alice, signer::address_of(bob), b"Solidity");
        skillshare::accept_request(bob, 1);
    }

    #[test(admin = @skillshare_addr, alice = @0xa)]
    #[expected_failure(abort_code = 1)]
    fun test_duplicate_registration(admin: &signer, alice: &signer) {
        account::create_account_for_test(signer::address_of(admin));
        skillshare::init_registration_events(admin);
        skillshare::register_user(alice, b"Alice");
        skillshare::register_user(alice, b"Alice"); // Should abort
    }

    #[test(admin = @skillshare_addr, alice = @0xa)]
    fun test_user_exists_view(admin: &signer, alice: &signer) {
        account::create_account_for_test(signer::address_of(admin));
        skillshare::init_registration_events(admin);
        skillshare::register_user(alice, b"Alice");
        assert!(skillshare::user_exists(signer::address_of(alice)), 100);
        assert!(!skillshare::user_exists(@0xdead), 101);
    }

    #[test(admin = @skillshare_addr, alice = @0xa, bob = @0xb)]
    fun test_reject_flow(admin: &signer, alice: &signer, bob: &signer) {
        account::create_account_for_test(signer::address_of(admin));
        skillshare::init_registration_events(admin);
        skillshare::init_global_requests(admin);
        skillshare::register_user(alice, b"Alice");
        skillshare::register_user(bob, b"Bob");
        skillshare::add_skill(bob, b"Move");
        skillshare::request_teach(alice, signer::address_of(bob), b"Move");
        skillshare::reject_request(bob, 1); // now rejected!
    }
}
