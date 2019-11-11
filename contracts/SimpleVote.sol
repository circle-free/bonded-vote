pragma solidity >=0.5.0 <0.7.0;

contract SimpleVote {
    constructor() public {}                             // no one owns this, and there are no paramaters of configurations

    function vote(uint256 proposalId, uint256 optionId) public {
        Proposal storage proposal = proposals[proposalId];
        uint256 proposalDeadline = proposal.deadline;   // keep a copy to save on SLOAD as deadline will be reused later on

        assert(proposalId < proposalCount)              // prevent voting on non-initialized proposals (cheaper than assert(proposals[proposalId].options))
        assert(block.number < proposalDeadline);        // note that block.number is the parent of the block this transaction will be included in
        assert(optionId < proposal.options);            // prevent the vote frombeing cast on an unavailable option

        bytes32 voteKey = getVoteKey(msg.sender, proposalId);                           // get the unique vote key for this account-proposal combination
        assert(voteRecords[voteKey] == 0);                                              // account must not have already voted on this proposal

        Account storage account = accounts[msg.sender];
        uint256 accountBalance = account.balance;       // keep a copy to save on SLOAD as balance will be reused later on
        voteRecords[voteKey] = accountBalance;          // record that account has voted on this proposal, and how much, (not the direction)

        if (account.unlockBlock < proposalDeadline) {
            account.unlockBlock = proposalDeadline;     // bond the account's balance until voting for this proposal ends
        }

        bytes32 optionKey = getOptionKey(proposalId, optionId);                         // get the unique option key for this option
        optionTallies[optionKey] += accountBalance;                                     // add support (in wei) to option (again, no need for safe math)

        bytes32 leadingOptionKey = getOptionKey(proposalId, proposal.leadingOption);    // get the unique option key for the proposal's leading option

        if (optionTallies[optionKey] >= optionTallies[leadingOptionKey]) {
            proposal.leadingOption = optionId;                                          // update the leading option if it has been overtaken
        }

        emit VoteCast(msg.sender, proposalId, optionId, accountBalance);
    }
}
