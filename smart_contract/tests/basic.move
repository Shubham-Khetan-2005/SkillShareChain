module 0x2::basic {
    use 0x1::skillshare;       // ← change 0x1 if you moved the module

    // 'alice' is a signer bound to address 0xA for this test only
    #[test(alice = @0xa)]
    fun it_registers(alice: signer) {
        skillshare::register_user(&alice, b"alice");
        skillshare::add_skill(&alice, b"solidity");
    }
}
