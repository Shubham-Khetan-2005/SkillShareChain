module skillshare_addr::skillshare {
    use std::signer;
    use std::vector;

    struct User has key {
        name: vector<u8>,
        skills: vector<vector<u8>>,
    }

    /// error code 1 = user already exists
    public entry fun register_user(acct: &signer, name: vector<u8>) {
        assert!(!exists<User>(signer::address_of(acct)), 1);
        move_to(acct, User { name, skills: vector::empty<vector<u8>>() });
    }

    /// error code 2 = user not found
    public entry fun add_skill(acct: &signer, skill: vector<u8>) acquires User {
        assert!(exists<User>(signer::address_of(acct)), 2);
        let user_ref = borrow_global_mut<User>(signer::address_of(acct));
        vector::push_back(&mut user_ref.skills, skill);
    }
}
