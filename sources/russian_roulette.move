module fliptos::russian_roulette {

    // Module for the Fliptos Russian Roulette
    // Implements the Native Randomness for a provably fair game

    use std::error;
    use std::signer;
    use std::vector;
    use std::string::String;
    use aptos_framework::coin;
    use aptos_framework::randomness;
    use aptos_framework::math64;
    use 0x1::aptos_coin::AptosCoin;
    use 0x1::event::emit;
    use aptos_std::type_info;
    use 0x1::fixed_point32::multiply_u64;
    use 0x1::fixed_point32;

    use fliptos::coinflip;

    const MAX_PAYOUT_APT: u64 = 5000_000_000;
    const BET_FEE_BPS: u64 = 500;
    const VAULT: address = @0xb4b029bb113999850d806c44a487545e2f3f3ef9ae787d7dbf09df98e4a1249f;

    #[randomness]
    entry fun play<CoinType>(
        player: &signer,
        amount: u64,
        chosen_bullets: vector<u64>,
        vault_owner: address // specifies against which vault player wants to bet
    ) {
        let player_address = signer::address_of(player);
        let coin_name = type_info::type_name<CoinType>();
        let apt_name = type_info::type_name<AptosCoin>();

        let nb_chosen_bullets = vector::length<u64>(&chosen_bullets);

        // player must choose max 5 numbers and at least 1
        assert!(nb_chosen_bullets < 6, error::resource_exhausted(0));
        assert!(nb_chosen_bullets >= 1, error::resource_exhausted(1));

        // bullet numbers must be unique
        if (!has_unique_numbers(&chosen_bullets)) {
            abort 4;
        };

        let payout = math64::mul_div(amount, 6, 6 - nb_chosen_bullets);

        // check potential payout is below max for APT
        if (coin_name == apt_name) {
            assert!(payout <= MAX_PAYOUT_APT, error::resource_exhausted(3));
        };
    
        let bullet_shot = randomness::u64_range(0, 6);

        // transfer bet amount to the vault
        let fee_multiplier = fixed_point32::create_from_rational(10000 + BET_FEE_BPS, 10000);
        let amount_with_fees = multiply_u64(amount, fee_multiplier);

        coin::transfer<CoinType>(player, VAULT, amount_with_fees);

        for (i in 0..nb_chosen_bullets) {
            let bullet = vector::borrow<u64>(&chosen_bullets, i);

            // check bullet numbers
            assert!(*bullet <= 5, error::resource_exhausted(2));
            assert!(*bullet >= 0, error::resource_exhausted(2));

            if (bullet == &bullet_shot) {

                emit(RussianRouletteEvent {
                    player: player_address,
                    is_won: false,
                    coin_name,
                    amount_bet: amount,
                    chosen_bullets,
                    bullet_shot
                });

                return
            };
        };

        coinflip::transfer<CoinType>(payout, vault_owner, player_address);

        emit(RussianRouletteEvent {
            player: player_address,
            is_won: true,
            coin_name,
            amount_bet: amount,
            chosen_bullets,
            bullet_shot
        });
    }

    #[event]
    struct RussianRouletteEvent has drop, store {
        player: address,
        is_won: bool,
        coin_name: String,
        amount_bet: u64,
        chosen_bullets: vector<u64>,
        bullet_shot: u64
    }

    fun has_unique_numbers(numbers: &vector<u64>): bool {
        let len = vector::length(numbers);
        
        for (i in 0..len) {
            let current = *vector::borrow(numbers, i);

            let next_id = i + 1;
            
            for (j in next_id..len) {
                if (current == *vector::borrow(numbers, j)) {
                    return false;
                };
            };
        };
        
        true
    }

    /// Errors
    /// Too many bullets chosen
    const E_TOO_MANY_BULLETS: u8 = 0;
    /// No bullet in gun
    const E_NO_BULLET: u8 = 1;
    /// Wrong bullet number
    const E_WRONG_BULLET: u8 = 2;
    /// Bet amount too high
    const E_MAX_BET_REACHED: u8 = 3;
    /// Duplicate bullet
    const E_DUPLICATE_BULLET: u8 = 4;
}
