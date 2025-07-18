module skillshare_addr::skillshare {
    use std::signer;
    use std::vector;
    use aptos_std::table::{Self, Table};
    use aptos_framework::event;
    use aptos_framework::account;
    use aptos_framework::coin;
    use aptos_framework::aptos_coin::AptosCoin;
    use aptos_framework::timestamp;


    // On-chain profile for each user
    struct User has key {
        name: vector<u8>,
        skills: vector<vector<u8>>,
        contact_info: vector<u8>,  // NEW: Private contact details
    }

    // A request from a learner to a teacher for a lesson
    struct TeachRequest has store {
        id: u64,
        learner: address,
        teacher: address,
        skill: vector<u8>,
        accepted: bool,
        rejected: bool,

        // Payment & Escrow Fields
        payment_deposited: bool,
        payment_amount: u64,
        deposit_timestamp: u64,
        
        // Communication & Coordination Fields
        teacher_acknowledged: bool,
        communication_started: bool,
        learner_reported_non_response: bool,
        
        // Completion & Release Fields
        teacher_confirmed_complete: bool,
        learner_confirmed_complete: bool,
        payment_released: bool,
        refund_claimed: bool,
    }

    // Global storage for all teach requests and events
    struct GlobalRequests has key {
        next_id: u64,
        requests: Table<u64, TeachRequest>,
        
        // Existing event handles
        request_events: event::EventHandle<TeachRequestedEvent>,
        accept_events: event::EventHandle<TeachAcceptedEvent>,
        rejected_events: event::EventHandle<TeachRejectedEvent>,
        
        // NEW: Payment & communication event handles
        payment_events: event::EventHandle<PaymentDepositedEvent>,
        acknowledgment_events: event::EventHandle<TeacherAcknowledgedEvent>,
        communication_events: event::EventHandle<CommunicationStartedEvent>,
        non_response_events: event::EventHandle<NonResponseReportedEvent>,
        release_events: event::EventHandle<PaymentReleasedEvent>,
        refund_events: event::EventHandle<RefundClaimedEvent>,
    }

    // Platform-wide configuration
    struct PlatformConfig has key {
        fixed_lesson_price: u64,        // 1 APT = 100000000 octas
        response_window_hours: u64,     // 24 hours
        minimum_lesson_duration: u64,   // 24 hours
    }

    // Event emitted when a teach request is created
    struct TeachRequestedEvent has drop, store {
        id: u64,
        learner: address,
        teacher: address,
        skill: vector<u8>,
    }

    // Payment-related events
    struct PaymentDepositedEvent has drop, store {
        request_id: u64,
        learner: address,
        teacher: address,
        amount: u64,
        timestamp: u64,
    }

    struct TeacherAcknowledgedEvent has drop, store {
        request_id: u64,
        teacher: address,
        timestamp: u64,
    }

    struct CommunicationStartedEvent has drop, store {
        request_id: u64,
        learner: address,
        timestamp: u64,
    }

    struct NonResponseReportedEvent has drop, store {
        request_id: u64,
        learner: address,
        timestamp: u64,
    }

    struct PaymentReleasedEvent has drop, store {
        request_id: u64,
        teacher: address,
        amount: u64,
        timestamp: u64,
    }

    struct RefundClaimedEvent has drop, store {
        request_id: u64,
        learner: address,
        amount: u64,
        timestamp: u64,
    }


    // Event emitted when a teach request is accepted
    struct TeachAcceptedEvent has drop, store {
        id: u64,
    }

    struct TeachRejectedEvent has drop, store {
        id: u64,
    }

    // Event emitted when a user registers
    struct UserRegisteredEvent has drop, store {
        addr: address,
        name: vector<u8>,
    }

    // Event handle for all registration events
    struct RegistrationEvents has key {
        handle: event::EventHandle<UserRegisteredEvent>,
    }

    // Enhanced registration with contact information
    // error code 7: contact info cannot be empty
    // error code 8: contact info too long (max 500 characters)
    public entry fun register_user_with_contact(
        acct: &signer, 
        name: vector<u8>,
        contact_info: vector<u8>
    ) acquires RegistrationEvents {
        let addr = signer::address_of(acct);
        assert!(!exists<User>(addr), 1);
        assert!(!vector::is_empty(&contact_info), 7);
        assert!(vector::length(&contact_info) <= 500, 8);

        move_to(acct, User { 
            name: copy name, 
            skills: vector::empty<vector<u8>>(),
            contact_info,
        });

        let events = borrow_global_mut<RegistrationEvents>(@skillshare_addr);
        event::emit_event<UserRegisteredEvent>(&mut events.handle, UserRegisteredEvent {
            addr,
            name,
        });
    }

    // Original registration (backward compatibility)
    // error code 1: user already exists
    // public entry fun register_user(acct: &signer, name: vector<u8>) acquires RegistrationEvents {
    //     assert!(!exists<User>(signer::address_of(acct)), 1);
    //     move_to(acct, User { name: copy name, skills: vector::empty<vector<u8>>() });

    //     let events = borrow_global_mut<RegistrationEvents>(@skillshare_addr);
    //     event::emit_event<UserRegisteredEvent>(&mut events.handle, UserRegisteredEvent {
    //         addr: signer::address_of(acct),
    //         name,
    //     });
    // }

    // Add a skill to the caller's profile
    // error code 2: user not found
    public entry fun add_skill(acct: &signer, skill: vector<u8>) acquires User {
        assert!(exists<User>(signer::address_of(acct)), 2);
        let user_ref = borrow_global_mut<User>(signer::address_of(acct));
        vector::push_back(&mut user_ref.skills, skill);
    }

    // Initialize global storage for teach requests and events (call once by admin)
    // Enhanced global requests initialization
    public entry fun init_global_requests(admin: &signer) {
        let addr = signer::address_of(admin);
        if (!exists<GlobalRequests>(addr)) {
            move_to(admin, GlobalRequests {
                next_id: 1,
                requests: table::new(),
                
                // Existing event handles
                request_events: account::new_event_handle<TeachRequestedEvent>(admin),
                accept_events: account::new_event_handle<TeachAcceptedEvent>(admin),
                rejected_events: account::new_event_handle<TeachRejectedEvent>(admin),
                
                // New payment & communication event handles
                payment_events: account::new_event_handle<PaymentDepositedEvent>(admin),
                acknowledgment_events: account::new_event_handle<TeacherAcknowledgedEvent>(admin),
                communication_events: account::new_event_handle<CommunicationStartedEvent>(admin),
                non_response_events: account::new_event_handle<NonResponseReportedEvent>(admin),
                release_events: account::new_event_handle<PaymentReleasedEvent>(admin),
                refund_events: account::new_event_handle<RefundClaimedEvent>(admin),
            });
        }
    }

    // Initialize registration event handle (call once by admin)
    public entry fun init_registration_events(admin: &signer) {
        if (!exists<RegistrationEvents>(@skillshare_addr)) {
            move_to(admin, RegistrationEvents {
                handle: account::new_event_handle<UserRegisteredEvent>(admin),
            });
        }
    }

    // Learner requests a lesson from a teacher for a specific skill
    // error code 3: teacher not registered
    public entry fun request_teach(
        learner: &signer,
        teacher: address,
        skill: vector<u8>
    ) acquires GlobalRequests {
        let learner_addr = signer::address_of(learner);

        // Validate teacher exists
        assert!(user_exists(teacher), 3);

        // ✅ Validate learner is registered
        assert!(user_exists(learner_addr), 2); // Error code 2: user not registered
    

        // Get global storage
        let global = borrow_global_mut<GlobalRequests>(@skillshare_addr);
        let id = global.next_id;

        // Create and store request with ALL fields initialized
        let request = TeachRequest {
            id,
            learner: learner_addr,
            teacher,
            skill: copy skill,
            accepted: false,
            rejected: false,
            
            // Initialize new Week 3 fields with default values
            payment_deposited: false,
            payment_amount: 0,
            deposit_timestamp: 0,
            teacher_acknowledged: false,
            communication_started: false,
            learner_reported_non_response: false,
            teacher_confirmed_complete: false,
            learner_confirmed_complete: false,
            payment_released: false,
            refund_claimed: false,
        };
        
        table::add(&mut global.requests, id, request);
        global.next_id = id + 1;

        // Emit event
        event::emit_event<TeachRequestedEvent>(&mut global.request_events, TeachRequestedEvent {
            id,
            learner: learner_addr,
            teacher,
            skill,
        });
    }


    // Teacher accepts a teach request by ID
    // error code 4: request not found
    // error code 5: not your request
    public entry fun accept_request(
        teacher: &signer,
        id: u64
    ) acquires GlobalRequests {
        let teacher_addr = signer::address_of(teacher);

        let global = borrow_global_mut<GlobalRequests>(@skillshare_addr);

        // Validate request exists
        assert!(table::contains(&global.requests, id), 4);
        let request = table::borrow_mut(&mut global.requests, id);

        // Validate teacher is correct
        assert!(request.teacher == teacher_addr, 5);

        // Update status
        request.accepted = true;

        // Emit event
        event::emit_event<TeachAcceptedEvent>(&mut global.accept_events, TeachAcceptedEvent {
            id,
        });
    }

    // Teacher rejects a teach request by ID
    // error code 4: request not found
    // error code 5: not your request
    // error code 6: already accepted or rejected
    public entry fun reject_request(
        teacher: &signer,
        id: u64
    ) acquires GlobalRequests {
        let teacher_addr = signer::address_of(teacher);
        let global = borrow_global_mut<GlobalRequests>(@skillshare_addr);

        // Validate request exists
        assert!(table::contains(&global.requests, id), 4);
        let request = table::borrow_mut(&mut global.requests, id);

        // Validate teacher is correct
        assert!(request.teacher == teacher_addr, 5);

        // Only pending requests can be rejected
        assert!(!request.accepted && !request.rejected, 6);

        request.rejected = true;

        event::emit_event<TeachRejectedEvent>(&mut global.rejected_events, TeachRejectedEvent {
            id,
        });
    }

    // Learner deposits 1 APT into escrow for accepted request
    // error code 9: payment already deposited
    // error code 10: insufficient balance
    // error code 11: request must be accepted first
    public entry fun deposit_payment(
        learner: &signer,
        request_id: u64
    ) acquires GlobalRequests, PlatformConfig {
        let learner_addr = signer::address_of(learner);
        let global = borrow_global_mut<GlobalRequests>(@skillshare_addr);
        let config = borrow_global<PlatformConfig>(@skillshare_addr);
        
        // Validate request exists and is accepted
        assert!(table::contains(&global.requests, request_id), 4);
        let request = table::borrow_mut(&mut global.requests, request_id);
        assert!(request.accepted && !request.rejected, 11);
        assert!(request.learner == learner_addr, 5);
        assert!(!request.payment_deposited, 9);
        
        // Check learner has sufficient balance
        let balance = coin::balance<AptosCoin>(learner_addr);
        assert!(balance >= config.fixed_lesson_price, 10);
        
        // CRITICAL: Ensure contract account is registered for AptosCoin
        if (!coin::is_account_registered<AptosCoin>(@skillshare_addr)) {
            // This should be done during initialization, but adding as safety check
            abort 23; // Add new error code for contract not registered
        };
        
        // Transfer APT to contract
        let payment = coin::withdraw<AptosCoin>(learner, config.fixed_lesson_price);
        coin::deposit<AptosCoin>(@skillshare_addr, payment);
        
        // Update request state
        request.payment_deposited = true;
        request.payment_amount = config.fixed_lesson_price;
        request.deposit_timestamp = timestamp::now_seconds();
        
        // Emit event
        event::emit_event<PaymentDepositedEvent>(&mut global.payment_events, PaymentDepositedEvent {
            request_id,
            learner: learner_addr,
            teacher: request.teacher,
            amount: config.fixed_lesson_price,
            timestamp: request.deposit_timestamp,
        });
    }

    // Teacher acknowledges payment and gains access to contact info
    // error code 12: payment not deposited
    // error code 13: already acknowledged
    public entry fun acknowledge_payment(
        teacher: &signer,
        request_id: u64
    ) acquires GlobalRequests {
        let teacher_addr = signer::address_of(teacher);
        let global = borrow_global_mut<GlobalRequests>(@skillshare_addr);
        
        // Validate request and teacher
        assert!(table::contains(&global.requests, request_id), 4);
        let request = table::borrow_mut(&mut global.requests, request_id);
        assert!(request.teacher == teacher_addr, 5);
        assert!(request.payment_deposited, 12);
        assert!(!request.teacher_acknowledged, 13);
        
        // Update acknowledgment status
        request.teacher_acknowledged = true;
        
        // Emit event
        event::emit_event<TeacherAcknowledgedEvent>(&mut global.acknowledgment_events, TeacherAcknowledgedEvent {
            request_id,
            teacher: teacher_addr,
            timestamp: timestamp::now_seconds(),
        });
    }

    // Get contact information for acknowledged payments
    // error code 14: contact access not authorized
    #[view]
    public fun get_contact_info(request_id: u64, requester: address): vector<u8> acquires GlobalRequests, User {
        let global = borrow_global<GlobalRequests>(@skillshare_addr);
        assert!(table::contains(&global.requests, request_id), 4);
        
        let request = table::borrow(&global.requests, request_id);
        assert!(request.teacher_acknowledged, 14);
        assert!(requester == request.teacher || requester == request.learner, 14);
        
        // Return appropriate contact info
        if (requester == request.teacher) {
            let learner_user = borrow_global<User>(request.learner);
            learner_user.contact_info
        } else {
            let teacher_user = borrow_global<User>(request.teacher);
            teacher_user.contact_info
        }
    }

    // Boolean view used by the front-end duplicate guard
    #[view]
    public fun user_exists(addr: address): bool {
        exists<User>(addr)
    }

    // Learner confirms teacher has made contact
    // error code 15: communication already started
    public entry fun learner_mark_communication_started(
        learner: &signer,
        request_id: u64
    ) acquires GlobalRequests {
        let learner_addr = signer::address_of(learner);
        let global = borrow_global_mut<GlobalRequests>(@skillshare_addr);
        
        // Validate request and learner
        assert!(table::contains(&global.requests, request_id), 4);
        let request = table::borrow_mut(&mut global.requests, request_id);
        assert!(request.learner == learner_addr, 5);
        assert!(request.teacher_acknowledged, 14);
        assert!(!request.communication_started, 15);
        
        // Mark communication as started
        request.communication_started = true;
        
        // Emit event
        event::emit_event<CommunicationStartedEvent>(&mut global.communication_events, CommunicationStartedEvent {
            request_id,
            learner: learner_addr,
            timestamp: timestamp::now_seconds(),
        });
    }

    // Learner reports teacher non-response for refund eligibility
    // error code 16: cannot report non-response yet (communication started)
    // error code 17: too early to report (less than 24 hours)
    public entry fun learner_report_non_response(
        learner: &signer,
        request_id: u64
    ) acquires GlobalRequests {
        let learner_addr = signer::address_of(learner);
        let global = borrow_global_mut<GlobalRequests>(@skillshare_addr);
        
        // Validate request and timing
        assert!(table::contains(&global.requests, request_id), 4);
        let request = table::borrow_mut(&mut global.requests, request_id);
        assert!(request.learner == learner_addr, 5);
        assert!(request.teacher_acknowledged, 14);
        assert!(!request.communication_started, 16);
        
        // Check 24 hours have passed since payment
        let hours_passed = (timestamp::now_seconds() - request.deposit_timestamp) / 3600;
        assert!(hours_passed >= 24, 17);
        
        // Mark non-response
        request.learner_reported_non_response = true;
        
        // Emit event
        event::emit_event<NonResponseReportedEvent>(&mut global.non_response_events, NonResponseReportedEvent {
            request_id,
            learner: learner_addr,
            timestamp: timestamp::now_seconds(),
        });
    }

    // Teacher requests payment release after lesson completion
    // error code 18: lesson completion already requested
    public entry fun teacher_request_release(
        teacher: &signer,
        request_id: u64
    ) acquires GlobalRequests {
        let teacher_addr = signer::address_of(teacher);
        let global = borrow_global_mut<GlobalRequests>(@skillshare_addr);
        
        // Validate request and teacher
        assert!(table::contains(&global.requests, request_id), 4);
        let request = table::borrow_mut(&mut global.requests, request_id);
        assert!(request.teacher == teacher_addr, 5);
        assert!(request.communication_started, 16);
        assert!(!request.teacher_confirmed_complete, 18);
        
        // Mark teacher completion
        request.teacher_confirmed_complete = true;
    }

    // Learner confirms completion and releases payment
    // error code 19: teacher hasn't requested release
    // error code 20: payment already released
    public entry fun learner_confirm_completion(
        learner: &signer,
        account: &signer,
        request_id: u64
    ) acquires GlobalRequests {
        let learner_addr = signer::address_of(learner);
        let global = borrow_global_mut<GlobalRequests>(@skillshare_addr);
        
        // Validate request and completion
        assert!(table::contains(&global.requests, request_id), 4);
        let request = table::borrow_mut(&mut global.requests, request_id);
        assert!(request.learner == learner_addr, 5);
        assert!(request.teacher_confirmed_complete, 19);
        assert!(!request.payment_released, 20);
        
        // Release payment to teacher
        let payment = coin::withdraw<AptosCoin>(account, request.payment_amount);
        coin::deposit<AptosCoin>(request.teacher, payment);
        
        // Update completion status
        request.learner_confirmed_complete = true;
        request.payment_released = true;
        
        // Emit event
        event::emit_event<PaymentReleasedEvent>(&mut global.release_events, PaymentReleasedEvent {
            request_id,
            teacher: request.teacher,
            amount: request.payment_amount,
            timestamp: timestamp::now_seconds(),
        });
    }

    // Learner claims refund for non-responsive teacher
    // error code 21: refund not available
    // error code 22: refund already claimed
    public entry fun claim_refund(
        learner: &signer,
        account: &signer,
        request_id: u64
    ) acquires GlobalRequests {
        let learner_addr = signer::address_of(learner);
        let global = borrow_global_mut<GlobalRequests>(@skillshare_addr);
        
        // Validate refund eligibility
        assert!(table::contains(&global.requests, request_id), 4);
        let request = table::borrow_mut(&mut global.requests, request_id);
        assert!(request.learner == learner_addr, 5);
        assert!(request.learner_reported_non_response, 21);
        assert!(!request.refund_claimed, 22);
        
        // Process refund
        let refund = coin::withdraw<AptosCoin>(account, request.payment_amount);
        coin::deposit<AptosCoin>(learner_addr, refund);
        
        // Update refund status
        request.refund_claimed = true;
        
        // Emit event
        event::emit_event<RefundClaimedEvent>(&mut global.refund_events, RefundClaimedEvent {
            request_id,
            learner: learner_addr,
            amount: request.payment_amount,
            timestamp: timestamp::now_seconds(),
        });
    }

    // Initialize platform configuration
    public entry fun init_platform_config(admin: &signer) {
        if (!exists<PlatformConfig>(@skillshare_addr)) {
            move_to(admin, PlatformConfig {
                fixed_lesson_price: 100000000, // 1 APT in octas
                response_window_hours: 24,
                minimum_lesson_duration: 24,
            });
        }
    }
}