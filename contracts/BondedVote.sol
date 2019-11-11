pragma solidity >=0.5.0 <0.7.0;

contract BondedVote {
    event DepositMade(address indexed account, uint256 indexed amount);
    event WithdrawalMade(address indexed account, address indexed destination, uint256 indexed amount);
    event ProposalCreated(uint256 indexed proposalId, uint256 indexed options, uint256 indexed deadline, bytes32 descriptionDigest);
    event VoteCast(address indexed account, uint256 indexed proposalId, uint256 indexed option, uint256 amount);

    struct Account {
        uint256 balance;        // an account's total withdrawable balance (sum of deposits since last withdrawal)
        uint256 unlockBlock;    // block number after which the balance can be withdrawn
    }

    struct Proposal {
        uint256 deadline;               // block number after which bonds can be released, and voting is no longer posssible
        bytes32 descriptionDigest;      // hash of some arbitray description for the proposal
        uint256 options;                // number of options for this proposal
        uint256 leadingOption;          // the leading option, kept up to date with each new vote cast
    }

    mapping(bytes32 => uint256) public voteRecords;     // used to check if an account has already voted, (helpful public historical query)
    mapping(address => Account) public accounts;
    mapping(uint256 => Proposal) public proposals;
    mapping(bytes32 => uint256) public optionTallies;   // effieicntly holds the tallies for all options, for all proposals

    uint256 public proposalCount = 0;                   // helps with indexing new proposals in mapping (helpful public query)

    constructor() public {}                             // no one owns this, and there are no paramaters of configurations

    function getVoteKey(address account, uint256 proposalId) public pure returns (bytes32) { return sha256(abi.encodePacked(account, proposalId)); }

    function getOptionKey(uint256 proposalId, uint256 optionId) public pure returns (bytes32) { return sha256(abi.encodePacked(proposalId, optionId)); }

    function() external payable { deposit(); }          // payable fallback redirects to deposit function (good for UX)

    function deposit() public payable {
        accounts[msg.sender].balance += msg.value;      // no need for safe math as the sum of all possible "value" on chain is les than MAX(uint256)
        emit DepositMade(msg.sender, msg.value);
    }

    function withdraw(address payable destination) public {
        Account storage account = accounts[msg.sender];
        assert(block.number >= account.unlockBlock);    // account's amount must not be staked to any proposal votes

        uint256 value = account.balance;
        account.balance = 0;                            // all or nothing ETH withrdrawal (in wei), before transfer to prevent reentrancy
        account.unlockBlock = 0;                        // this is moot, but at least frees up some state and reclaims some gas

        destination.transfer(value);
        emit WithdrawalMade(msg.sender, destination, value);
    }

    function createProposal(uint256 deadline, uint256 options, bytes32 descriptionDigest) public {
        assert(deadline > block.number);                // deadline must be at least current block
        assert(options > 0);                            // the proposal must have at least 1 option
        uint256 proposalId = proposalCount++;           // note that proposalId = proposalCount, then proposalCount is incremented

        Proposal storage proposal = proposals[proposalId];
        proposal.deadline = deadline;
        proposal.descriptionDigest = descriptionDigest;
        proposal.options = options;

        emit ProposalCreated(proposalId, options, deadline, descriptionDigest);
    }

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
