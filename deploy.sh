#!/bin/bash

echo "Deploying SkillShareChain..."

# Run tests first
echo "Running tests..."
cd smart_contract
aptos move test
if [ $? -ne 0 ]; then
    echo "Tests failed! Deployment aborted. ❌"
    exit 1
fi

# Deploy
echo "Deploying to shared account..."
aptos move publish --profile skillshare-shared

echo "Deployment complete! ✅"
cd ..
ACCOUNT_ADDRESS=0x$(aptos config show-profiles --profile skillshare-shared | jq -r '.Result | .[].account')
echo "Contract address: $ACCOUNT_ADDRESS"

echo "------------------------------------------------------------------------------------------------------"

# 5. Initialize platform configuration
cd smart_contract
echo "----------------------Initializing platform components---------------------------"
aptos move run \
  --function-id "0x4d28dbb7cbe3ce446f814aec4221c9575038bd7809155246be383674485026cb::skillshare::init_platform_config" \
  --profile skillshare-shared

# 6. Initialize global request system
echo "----------------------Initializing global request system---------------------------"
aptos move run \
  --function-id "0x4d28dbb7cbe3ce446f814aec4221c9575038bd7809155246be383674485026cb::skillshare::init_global_requests" \
  --profile skillshare-shared

# 7. Initialize registration events
echo "----------------------Initializing registration events---------------------------"
aptos move run \
  --function-id "0x4d28dbb7cbe3ce446f814aec4221c9575038bd7809155246be383674485026cb::skillshare::init_registration_events" \
  --profile skillshare-shared
