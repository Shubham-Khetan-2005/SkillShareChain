module 0x2::basic {
    use skillshare_addr::skillshare;
    use aptos_framework::account;

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
}
