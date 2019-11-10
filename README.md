# BondedVote

An on-chain bonded vote mechanism, that requires Ether to be bonded for the length of a proposal's voting window. This allows the on-chain vote tally to be accrued with each vote, to be accurate, permanent, and, unlike a carbon vote, to be computed and queried on-chain. No off-chain queries or computations (looped or otherwise), are needed. Further, by supporting a indefinite number or proposals, and bonding an account's Ether for the duration of the longest proposal it has participated in, this ensures Ether bonded for voting in one proposal can be used to vote in another proposal.

## Project Status
This is beta and has not yet been deployed to mainnet, however, it is relatively simple, and thus not risky to use with real Ether. 

Documentation and rationale (aside from contract comments) are coming.

## Source layout

The default source layout:

```
contracts
└── BondedVote.sol
```

* `BondedVote.sol` entire smart contract (Solidity) that needs to only be deployed as a singleton on a blockchain, as it is ownerless

## Notes

* Having more than one actively used BondedVote contract on a chain is actually counter-productive, as it prevents the same ETH from being bonded to vote on more than unrelated proposal. This contract already handles this.