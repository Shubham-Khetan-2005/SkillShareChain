#[test_only]
module skillshare_addr::test_helpers {
    use skillshare_addr::skillshare;
    use aptos_framework::account;
    use aptos_framework::coin;
    use aptos_framework::aptos_coin::{Self, AptosCoin};
    use aptos_framework::timestamp;
    use std::signer;
    use std::vector;
    use std::bcs;

    // ==================== CORE SETUP FUNCTIONS ====================

    /// Initialize complete test environment with all required components
    /// NOTE: Does NOT initialize timestamp - call this for non-payment tests
    public fun setup_test_environment(admin: &signer) {
        account::create_account_for_test(signer::address_of(admin));
        
        // Initialize Aptos coin system for testing
        aptos_coin::ensure_initialized_with_apt_fa_metadata_for_test();
        
        // CRITICAL: Register the contract account for AptosCoin
        coin::register<AptosCoin>(admin);
        
        // Initialize platform components
        skillshare::init_platform_config(admin);
        skillshare::init_global_requests(admin);
        skillshare::init_registration_events(admin);
    }

    /// Initialize test environment with timestamp support for payment/time-based tests
    public fun setup_test_environment_with_timestamp(admin: &signer, framework: &signer) {
        // Initialize timestamp system FIRST
        timestamp::set_time_has_started_for_testing(framework);
        
        // Then setup regular environment
        setup_test_environment(admin);
    }

    /// Setup user account with APT balance
    public fun setup_coin_balance(user: &signer, amount: u64) {
        let user_addr = signer::address_of(user);
        
        // Ensure account exists
        if (!account::exists_at(user_addr)) {
            account::create_account_for_test(user_addr);
        };
        
        // Register for AptosCoin if not already registered
        if (!coin::is_account_registered<AptosCoin>(user_addr)) {
            coin::register<AptosCoin>(user);
        };
        
        // Initialize the coin system if needed
        if (!coin::is_coin_initialized<AptosCoin>()) {
            aptos_coin::ensure_initialized_with_apt_fa_metadata_for_test();
        };
        
        // Mint coins
        let aptos_framework = account::create_signer_for_test(@aptos_framework);
        aptos_coin::mint(&aptos_framework, user_addr, amount);
    }

    /// Register a user with realistic contact information and coin registration
    public fun register_user_with_default_contact(
        user: &signer, 
        name: vector<u8>,
        username: vector<u8>
    ) {
        // CRITICAL: Create account FIRST
        let user_addr = signer::address_of(user);
        account::create_account_for_test(user_addr);
        
        // Create realistic contact info
        let contact_info = b"Discord: ";
        vector::append(&mut contact_info, username);
        vector::append(&mut contact_info, b"#1234, Email: ");
        vector::append(&mut contact_info, username);
        vector::append(&mut contact_info, b"@skillshare.com");
        
        // Register user in your platform FIRST
        skillshare::register_user_with_contact(user, name, contact_info);
        
        // THEN register for AptosCoin (only if needed for payment tests)
        coin::register<AptosCoin>(user);
    }

    /// Simple user registration without coin setup
    public fun register_user_simple(
        user: &signer, 
        name: vector<u8>,
        username: vector<u8>
    ) {
        let user_addr = signer::address_of(user);
        account::create_account_for_test(user_addr);
        
        let contact_info = b"Discord: ";
        vector::append(&mut contact_info, username);
        vector::append(&mut contact_info, b"#1234, Email: ");
        vector::append(&mut contact_info, username);
        vector::append(&mut contact_info, b"@skillshare.com");
        
        skillshare::register_user_with_contact(user, name, contact_info);
    }

    // ==================== MULTI-STEP SETUP FUNCTIONS ====================

    /// Setup two users with skills and a basic request (no payment/timestamp needed)
    public fun setup_users_and_request(
        admin: &signer,
        alice: &signer, 
        bob: &signer
    ): u64 {
        setup_test_environment(admin);
        
        // Register users with contact info
        register_user_with_default_contact(alice, b"Alice", b"alice");
        register_user_with_default_contact(bob, b"Bob", b"bob");
        
        // Add skills
        skillshare::add_skill(bob, b"Solidity");
        skillshare::add_skill(bob, b"React");
        skillshare::add_skill(alice, b"Python");
        
        // Create and accept request
        skillshare::request_teach(alice, signer::address_of(bob), b"Solidity");
        skillshare::accept_request(bob, 1);
        
        1 // Return request ID
    }

    /// Setup complete payment flow (deposit + acknowledgment)
    /// REQUIRES: timestamp must be initialized before calling this function
    public fun setup_payment_flow(
        admin: &signer,
        alice: &signer,
        bob: &signer
    ): u64 {
        let request_id = setup_users_and_request(admin, alice, bob);
        
        // Give Alice 2 APT for payment + gas
        setup_coin_balance(alice, 200000000);
        
        // Deposit payment (REQUIRES timestamp to be initialized)
        skillshare::deposit_payment(alice, request_id);
        
        request_id
    }

    /// Setup payment with teacher acknowledgment
    /// REQUIRES: timestamp must be initialized before calling this function
    public fun setup_acknowledged_payment(
        admin: &signer,
        alice: &signer,
        bob: &signer
    ): u64 {
        let request_id = setup_payment_flow(admin, alice, bob);
        
        // Teacher acknowledges payment
        skillshare::acknowledge_payment(bob, request_id);
        
        request_id
    }

    /// Setup communication started flow
    /// REQUIRES: timestamp must be initialized before calling this function
    public fun setup_communication_started(
        admin: &signer,
        alice: &signer,
        bob: &signer
    ): u64 {
        let request_id = setup_acknowledged_payment(admin, alice, bob);
        
        // Learner marks communication as started
        skillshare::learner_mark_communication_started(alice, request_id);
        
        request_id
    }

    /// Setup complete lesson ready for completion
    /// REQUIRES: timestamp must be initialized before calling this function
    public fun setup_lesson_completion_ready(
        admin: &signer,
        alice: &signer,
        bob: &signer
    ): u64 {
        let request_id = setup_communication_started(admin, alice, bob);
        
        // Teacher requests release
        skillshare::teacher_request_release(bob, request_id);
        
        request_id
    }

    // ==================== TIME MANIPULATION FUNCTIONS ====================
    // NOTE: These functions require timestamp to be initialized before use

    /// Fast forward time by specified hours
    /// REQUIRES: timestamp::set_time_has_started_for_testing() must be called first
    public fun advance_time_by_hours(hours: u64) {
        let seconds = hours * 3600;
        timestamp::fast_forward_seconds(seconds);
    }

    /// Fast forward time by specified days
    /// REQUIRES: timestamp::set_time_has_started_for_testing() must be called first
    public fun advance_time_by_days(days: u64) {
        advance_time_by_hours(days * 24);
    }

    /// Get current timestamp for testing
    /// REQUIRES: timestamp::set_time_has_started_for_testing() must be called first
    public fun current_timestamp(): u64 {
        timestamp::now_seconds()
    }

    // ==================== VALIDATION HELPER FUNCTIONS ====================

    /// Check if user exists and is properly registered
    public fun assert_user_registered(user_addr: address) {
        assert!(skillshare::user_exists(user_addr), 1001);
    }

    /// Verify contact info is accessible after acknowledgment
    public fun assert_contact_accessible(request_id: u64, requester: address) {
        let contact = skillshare::get_contact_info(request_id, requester);
        assert!(!vector::is_empty(&contact), 1002);
    }

    /// Assert user has expected APT balance
    public fun assert_balance_equals(user_addr: address, expected: u64) {
        let actual = coin::balance<AptosCoin>(user_addr);
        assert!(actual == expected, 1003);
    }

    /// Assert user has at least minimum APT balance
    public fun assert_balance_at_least(user_addr: address, minimum: u64) {
        let actual = coin::balance<AptosCoin>(user_addr);
        assert!(actual >= minimum, 1004);
    }

    // ==================== MULTI-USER SETUP FUNCTIONS ====================

    /// Create predefined test addresses to avoid arithmetic
    public fun get_test_addresses(): vector<address> {
        vector[
            @0x1000, @0x1001, @0x1002, @0x1003, @0x1004,
            @0x1005, @0x1006, @0x1007, @0x1008, @0x1009,
            @0x100a, @0x100b, @0x100c, @0x100d, @0x100e,
            @0x100f, @0x1010, @0x1011, @0x1012, @0x1013
        ]
    }

    /// Setup multiple users for performance testing using predefined addresses
    /// REQUIRES: timestamp must be initialized before calling if using payments
    public fun setup_multiple_users(admin: &signer, count: u64): vector<address> {
        setup_test_environment(admin);
        
        let test_addresses = get_test_addresses();
        let users = vector::empty<address>();
        let i = 0;
        
        while (i < count && i < vector::length(&test_addresses)) {
            let user_addr = *vector::borrow(&test_addresses, i);
            let user = account::create_signer_for_test(user_addr);
            
            // Create unique username
            let username = b"user";
            let name = copy username;
            vector::append(&mut username, bcs::to_bytes(&i));
            vector::append(&mut name, bcs::to_bytes(&i));
            
            register_user_with_default_contact(&user, name, username);
            skillshare::add_skill(&user, b"TestSkill");
            
            // Give each user 5 APT
            setup_coin_balance(&user, 500000000);
            
            vector::push_back(&mut users, user_addr);
            i = i + 1;
        };
        
        users
    }

    /// Create multiple concurrent requests for testing
    public fun create_multiple_requests(
        teacher_addr: address,
        learner_addresses: &vector<address>,
        skill: vector<u8>
    ): vector<u64> {
        let request_ids = vector::empty<u64>();
        let i = 0;
        let count = vector::length(learner_addresses);
        
        while (i < count) {
            let learner_addr = *vector::borrow(learner_addresses, i);
            let learner = account::create_signer_for_test(learner_addr);
            
            skillshare::request_teach(&learner, teacher_addr, copy skill);
            
            // Request IDs start from 1 and increment
            vector::push_back(&mut request_ids, i + 1);
            i = i + 1;
        };
        
        request_ids
    }

    // ==================== ERROR TESTING HELPERS ====================

    /// Setup scenario for testing insufficient balance
    /// REQUIRES: timestamp must be initialized before calling this function
    public fun setup_insufficient_balance_scenario(
        admin: &signer,
        alice: &signer,
        bob: &signer
    ): u64 {
        let request_id = setup_users_and_request(admin, alice, bob);
        
        // Give Alice less than 1 APT (0.5 APT)
        setup_coin_balance(alice, 50000000);
        
        request_id
    }

    /// Setup scenario for testing non-response refund
    /// REQUIRES: timestamp must be initialized before calling this function
    public fun setup_non_response_scenario(
        admin: &signer,
        alice: &signer,
        bob: &signer
    ): u64 {
        let request_id = setup_acknowledged_payment(admin, alice, bob);
        
        // Advance time by 25 hours (past 24-hour deadline)
        advance_time_by_hours(25);
        
        request_id
    }
}
