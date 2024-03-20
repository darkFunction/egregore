# Egregore BITCOIN lottery

- Users approve contract to spend BITCOIN then call `sacrifice` to pay penitence and enter. One token = one chance.
- End time is 4/20/2024 00:00:00 UTC (+/- 900s for miner interference)
- LINK should be provided before this date to power the drawer (< 2 LINK @ current prices)
- Draw closes after 4/20/24 when anyone calls `beginCeremony`
- Chainlink VRF will set a random number on the contract
- Anyone can then call `payout` which will pay the lucky winner their stake + half the pot. Other half of pot goes to burn address 0x...dEaD
- Safety function for owner to retry `beginCeremony` if LINK was not sufficient or VRF callback failed

To run `forge test` you'll need to create a `.env` file containing your RPC endpoint, eg,

```
RPC_MAINNET="https://mainnet.infura.io/v3/<secret>"
```
