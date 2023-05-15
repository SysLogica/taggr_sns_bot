# taggr_sns_bot

## SNS Testflight

Follow this guide for instructions on how to test SNS specific functionalities for upgrading the dapp through proposals. This can be tested locally following this guide: https://internetcomputer.org/docs/current/developer-docs/integrations/sns/get-sns/testflight

## Running the project locally

If you want to test your project locally, you can use the following commands:

```bash
# Starts the replica, running in the background
dfx start --background

# Install SNS canisters with SNS1 principals locally (MUST USE DFX 0.14.x+)
dfx canister create sns_governance --specified-id zqfso-syaaa-aaaaq-aaafq-cai
dfx canister create sns_index --specified-id zlaol-iaaaa-aaaaq-aaaha-cai
dfx canister create sns_ledger --specified-id zfcdd-tqaaa-aaaaq-aaaga-cai
dfx canister create sns_root --specified-id zxeu2-7aaaa-aaaaq-aaafa-cai
dfx canister create sns_swap --specified-id zcdfx-6iaaa-aaaaq-aaagq-cai

# Deploy the testflight SNS
sns-cli deploy-testflight

# Set the SNS root as a controller of the bot
dfx canister update-settings --add-controller $(dfx canister id sns_root) taggr_sns_backend

# Deploys your canisters to the replica and generates your candid interface
dfx deploy

# The rest you can follow from step 5 onward here: https://internetcomputer.org/docs/current/developer-docs/integrations/sns/get-sns/testflight/#7-test-executing-code-on-sns-managed-canisters-via-sns-proposals
```
