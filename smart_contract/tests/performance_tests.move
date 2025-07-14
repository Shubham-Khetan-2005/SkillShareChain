#[test_only]
module skillshare_addr::performance_tests {
    use skillshare_addr::skillshare;
    use skillshare_addr::test_helpers;
    use aptos_framework::account;
    use aptos_framework::coin;
    use aptos_framework::aptos_coin::AptosCoin;
    use aptos_framework::timestamp;
    use std::vector;
    use std::bcs;

    // ==================== SCALABILITY TESTING ====================

    #[test(admin = @skillshare_addr, framework = @aptos_framework)]
    fun test_large_scale_user_registration(admin: &signer, framework: &signer) {
        timestamp::set_time_has_started_for_testing(framework);
        test_helpers::setup_test_environment(admin);
        
        let test_addresses = test_helpers::get_test_addresses();
        let total_users = vector::length(&test_addresses);
        let registered_count = 0;
        
        let i = 0;
        while (i < total_users) {
            let user_addr = *vector::borrow(&test_addresses, i);
            let user = account::create_signer_for_test(user_addr);
            
            // Create unique user data
            let username = b"user";
            vector::append(&mut username, bcs::to_bytes(&i));
            let name = copy username;
            vector::append(&mut name, b"_performance");
            
            test_helpers::register_user_with_default_contact(&user, name, username);
            
            // Add multiple skills per user
            skillshare::add_skill(&user, b"JavaScript");
            skillshare::add_skill(&user, b"Python");
            skillshare::add_skill(&user, b"React");
            
            // Verify registration succeeded
            assert!(skillshare::user_exists(user_addr), 501);
            registered_count = registered_count + 1;
            
            i = i + 1;
        };
        
        // Verify all users registered successfully
        assert!(registered_count == total_users, 502);
    }

    #[test(admin = @skillshare_addr, framework = @aptos_framework)]
    fun test_massive_concurrent_requests(admin: &signer, framework: &signer) {
        timestamp::set_time_has_started_for_testing(framework);
        test_helpers::setup_test_environment(admin);
        
        let test_addresses = test_helpers::get_test_addresses();
        
        // Setup one super teacher
        let teacher_addr = *vector::borrow(&test_addresses, 0);
        let teacher = account::create_signer_for_test(teacher_addr);
        test_helpers::register_user_with_default_contact(&teacher, b"SuperTeacher", b"superteacher");
        skillshare::add_skill(&teacher, b"AdvancedSkill");
        
        // Create many learners requesting from the same teacher
        let learner_count = 15; // Use subset for performance testing
        let i = 1;
        while (i <= learner_count) {
            let learner_addr = *vector::borrow(&test_addresses, i);
            let learner = account::create_signer_for_test(learner_addr);
            
            let username = b"learner";
            vector::append(&mut username, bcs::to_bytes(&i));
            test_helpers::register_user_with_default_contact(&learner, copy username, username);
            
            // Create teaching request
            skillshare::request_teach(&learner, teacher_addr, b"AdvancedSkill");
            
            i = i + 1;
        };
        
        // Teacher accepts all requests in batch
        let request_id = 1;
        while (request_id <= learner_count) {
            skillshare::accept_request(&teacher, request_id);
            request_id = request_id + 1;
        };
        
        // Verify all requests were processed
        // In a real implementation, you'd add view functions to verify request states
    }

    #[test(admin = @skillshare_addr, framework = @aptos_framework)]
    fun test_high_volume_payment_processing(admin: &signer, framework: &signer) {
        timestamp::set_time_has_started_for_testing(framework);
        test_helpers::setup_test_environment(admin);
        
        let test_addresses = test_helpers::get_test_addresses();
        
        // Setup teacher
        let teacher_addr = *vector::borrow(&test_addresses, 0);
        let teacher = account::create_signer_for_test(teacher_addr);
        test_helpers::register_user_with_default_contact(&teacher, b"VolumeTeacher", b"volumeteacher");
        skillshare::add_skill(&teacher, b"HighDemandSkill");
        
        let payment_count = 10; // Reduced for testing efficiency
        let total_volume = 0u64;
        
        // Process multiple payments
        let i = 1;
        while (i <= payment_count) {
            let learner_addr = *vector::borrow(&test_addresses, i);
            let learner = account::create_signer_for_test(learner_addr);
            
            let username = b"payer";
            vector::append(&mut username, bcs::to_bytes(&i));
            test_helpers::register_user_with_default_contact(&learner, copy username, username);
            
            // Setup request and payment flow
            skillshare::request_teach(&learner, teacher_addr, b"HighDemandSkill");
            skillshare::accept_request(&teacher, i);
            
            // Fund and process payment
            test_helpers::setup_coin_balance(&learner, 200000000); // 2 APT
            skillshare::deposit_payment(&learner, i);
            skillshare::acknowledge_payment(&teacher, i);
            skillshare::learner_mark_communication_started(&learner, i);
            skillshare::teacher_request_release(&teacher, i);
            skillshare::learner_confirm_completion(&learner, admin, i);
            
            total_volume = total_volume + 100000000; // 1 APT per payment
            i = i + 1;
        };
        
        // Verify teacher received all payments
        let teacher_balance = coin::balance<AptosCoin>(teacher_addr);
        assert!(teacher_balance >= total_volume, 503);
    }

    // ==================== STRESS TESTING ====================

    #[test(admin = @skillshare_addr, framework = @aptos_framework)]
    fun test_rapid_fire_operations(admin: &signer, framework: &signer) {
        timestamp::set_time_has_started_for_testing(framework);
        test_helpers::setup_test_environment(admin);
        
        let test_addresses = test_helpers::get_test_addresses();
        
        // Test rapid succession of operations without delays
        let operations_count = 8;
        let i = 0;
        
        while (i < operations_count) {
            let learner_addr = *vector::borrow(&test_addresses, (i * 2) + 1);
            let teacher_addr = *vector::borrow(&test_addresses, (i * 2) + 2);
            
            let learner = account::create_signer_for_test(learner_addr);
            let teacher = account::create_signer_for_test(teacher_addr);
            
            let learner_name = b"rapidlearner";
            vector::append(&mut learner_name, bcs::to_bytes(&i));
            let teacher_name = b"rapidteacher";
            vector::append(&mut teacher_name, bcs::to_bytes(&i));
            
            // Rapid registration
            test_helpers::register_user_with_default_contact(&learner, copy learner_name, learner_name);
            test_helpers::register_user_with_default_contact(&teacher, copy teacher_name, teacher_name);
            
            // Rapid skill and request processing
            skillshare::add_skill(&teacher, b"RapidSkill");
            skillshare::request_teach(&learner, teacher_addr, b"RapidSkill");
            skillshare::accept_request(&teacher, i + 1);
            
            // Rapid payment processing
            test_helpers::setup_coin_balance(&learner, 200000000);
            skillshare::deposit_payment(&learner, i + 1);
            skillshare::acknowledge_payment(&teacher, i + 1);
            skillshare::learner_mark_communication_started(&learner, i + 1);
            skillshare::teacher_request_release(&teacher, i + 1);
            skillshare::learner_confirm_completion(&learner, admin, i + 1);
            
            i = i + 1;
        };
        
        // Verify all operations completed successfully
        assert!(i == operations_count, 504);
    }

    #[test(admin = @skillshare_addr, framework = @aptos_framework)]
    fun test_complex_multi_party_interactions(admin: &signer, framework: &signer) {
        timestamp::set_time_has_started_for_testing(framework);
        test_helpers::setup_test_environment(admin);
        
        let test_addresses = test_helpers::get_test_addresses();
        
        // Create complex interaction web: everyone teaches and learns from everyone
        let participant_count = 6; // Manageable number for complex interactions
        let i = 0;
        
        // Setup all participants
        while (i < participant_count) {
            let participant_addr = *vector::borrow(&test_addresses, i);
            let participant = account::create_signer_for_test(participant_addr);
            
            let username = b"participant";
            vector::append(&mut username, bcs::to_bytes(&i));
            test_helpers::register_user_with_default_contact(&participant, copy username, username);
            
            // Each participant has unique skills
            let skill = b"Skill";
            vector::append(&mut skill, bcs::to_bytes(&i));
            skillshare::add_skill(&participant, skill);
            
            // Fund each participant
            test_helpers::setup_coin_balance(&participant, 1000000000); // 10 APT
            
            i = i + 1;
        };
        
        // Create cross-requests: each participant requests from all others
        let request_id = 1;
        let learner_idx = 0;
        while (learner_idx < participant_count) {
            let teacher_idx = 0;
            while (teacher_idx < participant_count) {
                if (learner_idx != teacher_idx) {
                    let learner_addr = *vector::borrow(&test_addresses, learner_idx);
                    let teacher_addr = *vector::borrow(&test_addresses, teacher_idx);
                    let learner = account::create_signer_for_test(learner_addr);
                    let teacher = account::create_signer_for_test(teacher_addr);
                    
                    let skill = b"Skill";
                    vector::append(&mut skill, bcs::to_bytes(&teacher_idx));
                    
                    // Create and process request
                    skillshare::request_teach(&learner, teacher_addr, skill);
                    skillshare::accept_request(&teacher, request_id);
                    skillshare::deposit_payment(&learner, request_id);
                    skillshare::acknowledge_payment(&teacher, request_id);
                    skillshare::learner_mark_communication_started(&learner, request_id);
                    skillshare::teacher_request_release(&teacher, request_id);
                    skillshare::learner_confirm_completion(&learner, admin, request_id);
                    
                    request_id = request_id + 1;
                };
                teacher_idx = teacher_idx + 1;
            };
            learner_idx = learner_idx + 1;
        };
        
        // Verify complex interaction web completed
        let expected_requests = participant_count * (participant_count - 1);
        assert!(request_id - 1 == expected_requests, 505);
    }

    // ==================== RESOURCE EFFICIENCY TESTING ====================

    #[test(admin = @skillshare_addr, framework = @aptos_framework)]
    fun test_memory_efficient_skill_management(admin: &signer, framework: &signer) {
        timestamp::set_time_has_started_for_testing(framework);
        test_helpers::setup_test_environment(admin);
        
        let test_addresses = test_helpers::get_test_addresses();
        let user_addr = *vector::borrow(&test_addresses, 0);
        let user = account::create_signer_for_test(user_addr);
        
        test_helpers::register_user_with_default_contact(&user, b"SkillMaster", b"skillmaster");
        
        // Add many skills to test storage efficiency
        let skill_count = 50;
        let i = 0;
        while (i < skill_count) {
            let skill = b"Skill_";
            vector::append(&mut skill, bcs::to_bytes(&i));
            vector::append(&mut skill, b"_Advanced_Programming_Language");
            skillshare::add_skill(&user, skill);
            i = i + 1;
        };
        
        // Verify user still exists and system handles large skill lists
        assert!(skillshare::user_exists(user_addr), 506);
    }

    #[test(admin = @skillshare_addr, framework = @aptos_framework)]
    fun test_efficient_contact_info_handling(admin: &signer, framework: &signer) {
        timestamp::set_time_has_started_for_testing(framework);
        test_helpers::setup_test_environment(admin);
        
        let test_addresses = test_helpers::get_test_addresses();
        
        // Test with maximum length contact information
        let contact_count = 10;
        let i = 0;
        
        while (i < contact_count) {
            let user_addr = *vector::borrow(&test_addresses, i);
            let user = account::create_signer_for_test(user_addr);
            
            // Create near-maximum length contact info (close to 500 chars)
            let contact = b"Discord: verylongusernamefortesting#1234, Email: verylongusernamefortesting@example.com, Telegram: @verylongusernamefortesting, LinkedIn: linkedin.com/in/verylongusernamefortesting, GitHub: github.com/verylongusernamefortesting, Available: Monday-Friday 9AM-5PM PST, Specialties: Advanced React Development, Node.js Backend Architecture, Database Design and Optimization, Cloud Computing with AWS and Azure";
            
            let username = b"longuser";
            vector::append(&mut username, bcs::to_bytes(&i));
            
            skillshare::register_user_with_contact(&user, copy username, contact);
            assert!(skillshare::user_exists(user_addr), 507);
            
            i = i + 1;
        };
    }

    // ==================== TIMING AND CONCURRENCY TESTING ====================

    #[test(admin = @skillshare_addr, framework = @aptos_framework)]
    fun test_concurrent_payment_deadlines(admin: &signer, framework: &signer) {
        timestamp::set_time_has_started_for_testing(framework);
        test_helpers::setup_test_environment(admin);
        
        let test_addresses = test_helpers::get_test_addresses();
        
        // Setup multiple learner-teacher pairs with staggered payments
        let pair_count = 8;
        let i = 0;
        
        while (i < pair_count) {
            let learner_addr = *vector::borrow(&test_addresses, i * 2);
            let teacher_addr = *vector::borrow(&test_addresses, (i * 2) + 1);
            let learner = account::create_signer_for_test(learner_addr);
            let teacher = account::create_signer_for_test(teacher_addr);
            
            let learner_name = b"timedlearner";
            vector::append(&mut learner_name, bcs::to_bytes(&i));
            let teacher_name = b"timedteacher";
            vector::append(&mut teacher_name, bcs::to_bytes(&i));
            
            test_helpers::register_user_with_default_contact(&learner, copy learner_name, learner_name);
            test_helpers::register_user_with_default_contact(&teacher, copy teacher_name, teacher_name);
            skillshare::add_skill(&teacher, b"TimedSkill");
            
            // Create request and payment
            skillshare::request_teach(&learner, teacher_addr, b"TimedSkill");
            skillshare::accept_request(&teacher, i + 1);
            test_helpers::setup_coin_balance(&learner, 200000000);
            skillshare::deposit_payment(&learner, i + 1);
            skillshare::acknowledge_payment(&teacher, i + 1);
            
            // Advance time differently for each pair
            if (i % 2 == 0) {
                // Some proceed normally
                skillshare::learner_mark_communication_started(&learner, i + 1);
                skillshare::teacher_request_release(&teacher, i + 1);
                skillshare::learner_confirm_completion(&learner, admin, i + 1);
            } else {
                // Others hit deadline
                test_helpers::advance_time_by_hours(25);
                skillshare::learner_report_non_response(&learner, i + 1);
                skillshare::claim_refund(&learner, admin, i + 1);
            };
            
            i = i + 1;
        };
    }

    #[test(admin = @skillshare_addr, framework = @aptos_framework)]
    fun test_time_manipulation_stress(admin: &signer, framework: &signer) {
        timestamp::set_time_has_started_for_testing(framework);
        test_helpers::setup_test_environment(admin);
        
        let test_addresses = test_helpers::get_test_addresses();
        let learner_addr = *vector::borrow(&test_addresses, 0);
        let teacher_addr = *vector::borrow(&test_addresses, 1);
        let learner = account::create_signer_for_test(learner_addr);
        let teacher = account::create_signer_for_test(teacher_addr);
        
        test_helpers::register_user_with_default_contact(&learner, b"TimeTestLearner", b"timelearner");
        test_helpers::register_user_with_default_contact(&teacher, b"TimeTestTeacher", b"timeteacher");
        skillshare::add_skill(&teacher, b"TimeSkill");
        
        // Test multiple time advancement scenarios
        let time_test_count = 5;
        let i = 0;
        
        while (i < time_test_count) {
            skillshare::request_teach(&learner, teacher_addr, b"TimeSkill");
            skillshare::accept_request(&teacher, i + 1);
            test_helpers::setup_coin_balance(&learner, 200000000);
            skillshare::deposit_payment(&learner, i + 1);
            skillshare::acknowledge_payment(&teacher, i + 1);
            
            // Test different time advancement patterns
            if (i == 0) {
                test_helpers::advance_time_by_hours(1);
            } else if (i == 1) {
                test_helpers::advance_time_by_hours(12);
            } else if (i == 2) {
                test_helpers::advance_time_by_hours(24);
            } else if (i == 3) {
                test_helpers::advance_time_by_hours(48);
            } else {
                test_helpers::advance_time_by_hours(72);
            };
            
            // All should allow communication start regardless of time
            skillshare::learner_mark_communication_started(&learner, i + 1);
            skillshare::teacher_request_release(&teacher, i + 1);
            skillshare::learner_confirm_completion(&learner, admin, i + 1);
            
            i = i + 1;
        };
    }

    // ==================== PLATFORM SCALABILITY TESTING ====================

    #[test(admin = @skillshare_addr, framework = @aptos_framework)]
    fun test_platform_wide_activity_simulation(admin: &signer, framework: &signer) {
        timestamp::set_time_has_started_for_testing(framework);
        test_helpers::setup_test_environment(admin);
        
        let test_addresses = test_helpers::get_test_addresses();
        
        // Simulate realistic platform activity patterns
        let active_users = 12;
        let skills_per_user = 3;
        let requests_per_user = 2;
        
        // Phase 1: User onboarding wave
        let i = 0;
        while (i < active_users) {
            let user_addr = *vector::borrow(&test_addresses, i);
            let user = account::create_signer_for_test(user_addr);
            
            let username = b"platformuser";
            vector::append(&mut username, bcs::to_bytes(&i));
            test_helpers::register_user_with_default_contact(&user, copy username, username);
            
            // Each user adds multiple skills
            let skill_idx = 0;
            while (skill_idx < skills_per_user) {
                let skill = b"PlatformSkill";
                vector::append(&mut skill, bcs::to_bytes(&i));
                vector::append(&mut skill, b"_");
                vector::append(&mut skill, bcs::to_bytes(&skill_idx));
                skillshare::add_skill(&user, skill);
                skill_idx = skill_idx + 1;
            };
            
            test_helpers::setup_coin_balance(&user, 500000000); // 5 APT per user
            i = i + 1;
        };
        
        // Phase 2: Request creation wave
        let request_id = 1;
        let learner_idx = 0;
        while (learner_idx < active_users && request_id <= (active_users * requests_per_user)) {
            let teacher_idx = (learner_idx + 1) % active_users; // Circular assignment
            
            if (learner_idx != teacher_idx) {
                let learner_addr = *vector::borrow(&test_addresses, learner_idx);
                let teacher_addr = *vector::borrow(&test_addresses, teacher_idx);
                let learner = account::create_signer_for_test(learner_addr);
                let teacher = account::create_signer_for_test(teacher_addr);
                
                let skill = b"PlatformSkill";
                vector::append(&mut skill, bcs::to_bytes(&teacher_idx));
                vector::append(&mut skill, b"_0");
                
                skillshare::request_teach(&learner, teacher_addr, skill);
                skillshare::accept_request(&teacher, request_id);
                skillshare::deposit_payment(&learner, request_id);
                skillshare::acknowledge_payment(&teacher, request_id);
                skillshare::learner_mark_communication_started(&learner, request_id);
                skillshare::teacher_request_release(&teacher, request_id);
                skillshare::learner_confirm_completion(&learner, admin, request_id);
                
                request_id = request_id + 1;
            };
            
            learner_idx = learner_idx + 1;
            if (learner_idx >= active_users) {
                learner_idx = 0; // Wrap around for multiple requests per user
            };
        };
        
        // Verify platform handled the activity load
        assert!(request_id > active_users, 508);
    }
}
