#[test_only]
module aptosino::test_helpers {

    use std::signer;
    
    use aptos_std::crypto_algebra;
    
    use aptos_framework::account;
    use aptos_framework::aptos_coin::{Self, AptosCoin};
    use aptos_framework::coin;
    use aptos_framework::coin::Coin;
    use aptos_framework::randomness;
    use aptos_framework::stake;
    use aptosino::house;

    public fun setup_tests(framework: &signer, aptosino: &signer, initial_deposit: u64) {
        crypto_algebra::enable_cryptography_algebra_natives(framework);
        stake::initialize_for_test(framework);
        randomness::initialize_for_testing(framework);
        account::create_account_for_test(signer::address_of(aptosino));
        coin::register<AptosCoin>(aptosino);
        aptos_coin::mint(framework, signer::address_of(aptosino), initial_deposit);
    }
    
    public fun setup_house(
        framework: &signer, 
        aptosino: &signer, 
        initial_deposit: u64, 
        min_bet: u64, 
        max_bet: u64, 
        max_multiplier: u64, 
    ) {
        setup_tests(framework, aptosino, initial_deposit);
        house::init(
            aptosino,
            initial_deposit,
            min_bet,
            max_bet,
            max_multiplier,
        );
    }

    public fun setup_house_with_player(
        framework: &signer,
        aptosino: &signer,
        player: &signer,
        initial_deposit: u64,
        min_bet: u64,
        max_bet: u64,
        max_multiplier: u64,
    ) {
        setup_house(framework, aptosino, initial_deposit, min_bet, max_bet, max_multiplier);
        account::create_account_for_test(signer::address_of(player));
        coin::register<AptosCoin>(player);
        aptos_coin::mint(framework, signer::address_of(player), max_bet + 1);
    }
    
    public fun mint_coins(framework: &signer, amount: u64): Coin<AptosCoin> {
        account::create_account_for_test(signer::address_of(framework));
        coin::register<AptosCoin>(framework);
        aptos_coin::mint(framework, signer::address_of(framework), amount);
        coin::withdraw<AptosCoin>(framework, amount)
    }
    
    public fun get_fee(amount: u64, fee_bps: u64, fee_denom: u64): u64 {
        (amount * fee_bps) / fee_denom
    }
}
