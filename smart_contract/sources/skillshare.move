module skillshare_addr::skillshare {
    use std::signer;
    use std::vector;
    // use std::string;
    use aptos_std::table::{Self, Table};
    use aptos_std::event::{Self, EventHandle};
    use aptos_framework::account;

    // User Struct
    struct User has key {
        name: vector<u8>,
        skills: vector<vector<u8>>,
    }

    // TeachRequest struct
    struct TeachRequest has store {
        id: u64,
        learner: address,
        teacher: address,
        skill: vector<u8>,
        accepted: bool,
    }

    // Global request storage
    struct GlobalRequests has key {
        next_id: u64,
        requests: Table<u64, TeachRequest>,
        request_events: EventHandle<TeachRequestedEvent>,
        accept_events: EventHandle<TeachAcceptedEvent>,
    }

    // Events
    struct TeachRequestedEvent has drop, store {
        id: u64,
        learner: address,
        teacher: address,
        skill: vector<u8>,
    }

    struct TeachAcceptedEvent has drop, store {
        id: u64,
    }
    /// error code 1 = user already exists
    public entry fun register_user(acct: &signer, name: vector<u8>) {
        assert!(!exists<User>(signer::address_of(acct)), 1);
        move_to(acct, User { name, skills: vector::empty<vector<u8>>() });
    }

    // Boolean view used by the front-end duplicate guard
    #[view]
    public fun user_exists(addr: address): bool {
        exists<User>(addr)
    }

    /// error code 2 = user not found
    public entry fun add_skill(acct: &signer, skill: vector<u8>) acquires User {
        assert!(exists<User>(signer::address_of(acct)), 2);
        let user_ref = borrow_global_mut<User>(signer::address_of(acct));
        vector::push_back(&mut user_ref.skills, skill);
    }


    // Teach Functions

    // Initialise global storage
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

    // Request to learn a skill
    public entry fun request_teach(
        learner: &signer,
        teacher: address,
        skill: vector<u8>
    ) acquires GlobalRequests {
        let learner_addr = signer::address_of(learner);

        // Validate teacher exists
        assert!(user_exists(teacher), 3); // Error 3: Teacher got registered

        // Get global storage
        let global = borrow_global_mut<GlobalRequests>(@skillshare_addr);
        let id = global.next_id;

        // Create and store request
        let request=TeachRequest {
            id,
            learner: learner_addr,
            teacher,
            skill: copy skill,
            accepted: false
        };
        table::add(&mut global.requests, id, request);
        global.next_id=id+1;

        //Emit event
        event::emit_event(&mut global.request_events, TeachRequestedEvent {
            id,
            learner: learner_addr,
            teacher,
            skill,
        });
    }

    // Teacher accepts request
    public entry fun accept_request(
        teacher: &signer,
        id: u64
    ) acquires GlobalRequests {
        let teacher_addr = signer::address_of(teacher); 
        let global=borrow_global_mut<GlobalRequests>(@skillshare_addr);

        // validate request exists
        assert!(table::contains(&global.requests, id), 4); //Error4:Request not found
        let request=table::borrow_mut(&mut global.requests, id);

        //validate teacher is correct
        assert!(request.teacher==teacher_addr, 5); //Error5: Not your request

        //update status
        request.accepted=true;

        //emit event
        event::emit_event(&mut global.accept_events, TeachAcceptedEvent {
            id,
        });
    }
}
