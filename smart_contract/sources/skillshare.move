module skillshare_addr::skillshare {
    use std::signer;
    use std::vector;
    use aptos_std::table::{Self, Table};
    use aptos_framework::event;
    use aptos_framework::account;


    /// On-chain profile for each user
    struct User has key {
        name: vector<u8>,
        skills: vector<vector<u8>>,
    }

    /// A request from a learner to a teacher for a lesson
    struct TeachRequest has store {
        id: u64,
        learner: address,
        teacher: address,
        skill: vector<u8>,
        accepted: bool,
    }

    /// Global storage for all teach requests and events
    struct GlobalRequests has key {
        next_id: u64,
        requests: Table<u64, TeachRequest>,
        request_events: event::EventHandle<TeachRequestedEvent>,
        accept_events: event::EventHandle<TeachAcceptedEvent>,
    }

    /// Event emitted when a teach request is created
    struct TeachRequestedEvent has drop, store {
        id: u64,
        learner: address,
        teacher: address,
        skill: vector<u8>,
    }

    /// Event emitted when a teach request is accepted
    struct TeachAcceptedEvent has drop, store {
        id: u64,
    }

    /// Event emitted when a user registers
    struct UserRegisteredEvent has drop, store {
        addr: address,
        name: vector<u8>,
    }

    /// Event handle for all registration events
    struct RegistrationEvents has key {
        handle: event::EventHandle<UserRegisteredEvent>,
    }

    /// Register a new user and emit a registration event
    /// error code 1: user already exists
    public entry fun register_user(acct: &signer, name: vector<u8>) acquires RegistrationEvents {
        assert!(!exists<User>(signer::address_of(acct)), 1);
        move_to(acct, User { name: copy name, skills: vector::empty<vector<u8>>() });

        let events = borrow_global_mut<RegistrationEvents>(@skillshare_addr);
        event::emit_event<UserRegisteredEvent>(&mut events.handle, UserRegisteredEvent {
            addr: signer::address_of(acct),
            name,
        });
    }

    /// Boolean view used by the front-end duplicate guard
    #[view]
    public fun user_exists(addr: address): bool {
        exists<User>(addr)
    }

    /// Add a skill to the caller's profile
    /// error code 2: user not found
    public entry fun add_skill(acct: &signer, skill: vector<u8>) acquires User {
        assert!(exists<User>(signer::address_of(acct)), 2);
        let user_ref = borrow_global_mut<User>(signer::address_of(acct));
        vector::push_back(&mut user_ref.skills, skill);
    }

    /// Initialize global storage for teach requests and events (call once by admin)
    public entry fun init_global_requests(admin: &signer) {
        let addr = signer::address_of(admin);
        if (!exists<GlobalRequests>(addr)) {
            move_to(admin, GlobalRequests {
                next_id: 1,
                requests: table::new(),
                request_events: account::new_event_handle<TeachRequestedEvent>(admin),
                accept_events: account::new_event_handle<TeachAcceptedEvent>(admin),
            });
        }
    }

    /// Initialize registration event handle (call once by admin)
    public entry fun init_registration_events(admin: &signer) {
        if (!exists<RegistrationEvents>(@skillshare_addr)) {
            move_to(admin, RegistrationEvents {
                handle: account::new_event_handle<UserRegisteredEvent>(admin),
            });
        }
    }

    /// Learner requests a lesson from a teacher for a specific skill
    /// error code 3: teacher not registered
    public entry fun request_teach(
        learner: &signer,
        teacher: address,
        skill: vector<u8>
    ) acquires GlobalRequests {
        let learner_addr = signer::address_of(learner);

        // Validate teacher exists
        assert!(user_exists(teacher), 3);

        // Get global storage
        let global = borrow_global_mut<GlobalRequests>(@skillshare_addr);
        let id = global.next_id;

        // Create and store request
        let request = TeachRequest {
            id,
            learner: learner_addr,
            teacher,
            skill: copy skill,
            accepted: false,
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

    /// Teacher accepts a teach request by ID
    /// error code 4: request not found
    /// error code 5: not your request
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
}
