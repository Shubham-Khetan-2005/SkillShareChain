module 0x2::basic {
    use skillshare_addr::skillshare;
    use aptos_framework::account;
    use std::signer;

    #[test(alice = @0xa)]
    fun it_registers(alice: signer) {
        skillshare::register_user(&alice, b"alice");
        skillshare::add_skill(&alice, b"solidity");
    }

    #[test]
    fun it_returns_false_if_not_registered() {
        let _tmp = account::create_signer_for_test(@0xAAA);
        assert!(!skillshare::user_exists(@0xAAA), 101);
    }

    //Teach request tests
    #[test(admin=@skillshare_addr, alice=@0xa, bob=@0xb)]
    fun test_request_flow(admin: &signer, alice: &signer, bob: &signer){
        // Setup
        account::create_account_for_test(signer::address_of(admin));
        account::create_account_for_test(signer::address_of(alice));
        account::create_account_for_test(signer::address_of(bob));

        //Initialize
        skillshare::init_global_requests(admin);
        skillshare::register_user(alice, b"Alice");
        skillshare::register_user(bob, b"Bob");
        skillshare::add_skill(bob, b"React");

        //create request
        skillshare::request_teach(alice, @0xb, b"React");

        //accept request
        skillshare::accept_request(bob, 1);
    }


    #[test(admin=@skillshare_addr, alice=@0xa, bob=@0xb)]
    #[expected_failure(abort_code=5)]
    fun test_accept_wrong_teacher(admin: &signer, alice: &signer, bob:&signer) {
        account::create_account_for_test(signer::address_of(admin));
        account::create_account_for_test(signer::address_of(alice));
        account::create_account_for_test(signer::address_of(bob));

        skillshare::init_global_requests(admin);
        skillshare::register_user(alice, b"Alice");
        skillshare::register_user(bob, b"Bob");
        skillshare::add_skill(bob, b"React");

        skillshare::request_teach(alice, @0xb, b"React");

        //alice tries to accept (should fail)
        skillshare::accept_request(alice, 1);


    }
}
