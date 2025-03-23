module fliptos::giveaway {

    // Module for the Fliptos Giveaway Distribution
    // Implements the Native Randomness for a provably fair giveaway distribution

    use std::signer;
    use std::vector;
    use std::string::String;
    use aptos_framework::randomness;
    use 0x1::event::emit;
    use aptos_std::type_info;
    use 0x1::aptos_account;

    #[randomness]
    entry fun distribute_random<CoinType>(
        giver: &signer,
        amount: u64,
        eligible_players: vector<address>,
    ) {

        let coin_name = type_info::type_name<CoinType>();
        
        let nb_eligible_players = vector::length<address>(&eligible_players);
 
        // pick a random winner
        let winner_index = randomness::u64_range(0, nb_eligible_players);

        let winner_address = *vector::borrow(&eligible_players, winner_index);

        // transfer amount to winner
        aptos_account::transfer_coins<CoinType>(giver, winner_address, amount);

        emit(GiveawayEvent {
                    giver: signer::address_of(giver),
                    winner: winner_address,
                    coin_name,
                    amount,
                    nb_eligible_players,
                });

    }

    #[event]
    struct GiveawayEvent has drop, store {
        giver: address,
        winner: address,
        coin_name: String,
        amount: u64,
        nb_eligible_players: u64
    }
}
