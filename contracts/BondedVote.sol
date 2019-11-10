pragma solidity >=0.5.0 <0.7.0;

contract BondedVote {
    event DepositMade(address indexed account, uint256 indexed amount);
    event WithdrawalMade(address indexed account, address indexed destination, uint256 indexed amount);
    event ProposalCreated(address indexed creator, uint256 indexed proposalId, uint256 indexed deadline, bytes32 descriptionDigest);
    event ProposalSupported(address indexed account, uint256 indexed proposalId, uint256 indexed amount);
    event ProposalOpposed(address indexed account, uint256 indexed proposalId, uint256 indexed amount);

    struct Account {
        uint256 balance;        // an account's total withdrawable balance (sum of deposits since last withdrawal)
        uint256 unlockBlock;    // block number after which the balance can be withdrawn
    }

    struct Proposal {
        uint256 deadline;               // block number after which bonds can be released, and voting is no longer posssible
        bytes32 descriptionDigest;      // hash of some arbitray description for the proposal
        uint256 opposition;             // total ETH (in wei) bonded in opposition of the proposal
        uint256 support;                // total ETH (in wei) bonded in support of the proposal
    }

    // instead of a bool, a uint allows for scalable on-chain voting incentives, while discouraging incentivizing based on the vote direction
    mapping(bytes32 => uint256) public voteRecords;     // used to check if an account has already voted, (helpful public historical query)
    mapping(address => Account) public accounts;
    mapping(uint256 => Proposal) public proposals;

    uint256 public proposalCount = 0;                   // helps with indexing new proposals in mapping (helpful public query)

    constructor() public {}                             // no one owns this, and there are no paramaters of configurations

    // salt the account address with the proposal id
    function getVoteKey(address account, uint256 proposalId) public pure returns (bytes32) { return sha256(abi.encodePacked(account, proposalId)); }

    function() external payable { deposit(); }          // payable fallback redirects to deposit function (good for UX)

    function deposit() public payable {
        accounts[msg.sender].balance += msg.value;      // no need for safe math as no one has more wei than a uint256
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

    function createProposal(uint256 deadline, bytes32 descriptionDigest) public {
        assert(deadline > block.number);                // deadline must be at least current block
        uint256 proposalId = proposalCount++;           // note that proposalId = proposalCount, then proposalCount is incremented

        Proposal storage proposal = proposals[proposalId];
        proposal.deadline = deadline;
        proposal.descriptionDigest = descriptionDigest;

        emit ProposalCreated(msg.sender, proposalId, deadline, descriptionDigest);
    }

    function vote(uint256 proposalId, bool support) public {
        Proposal storage proposal = proposals[proposalId];
        assert(block.number < proposal.deadline);       // note that block.number is the parent of the block this transaction will be included in

        bytes32 voteKey = getVoteKey(msg.sender, proposalId);
        assert(voteRecords[voteKey] == 0);              // account must not have already voted on this proposal

        Account storage account = accounts[msg.sender];
        voteRecords[voteKey] = account.balance;         // record that account has voted on this proposal, and how much, (not the direction)

        if (account.unlockBlock < proposal.deadline) {
            account.unlockBlock = proposal.deadline;    // bond the account's balance until voting for this proposal ends
        }

        if (support) {
            proposal.support += account.balance;        // add support (in wei) to proposal (again, no need for safe math)
            emit ProposalSupported(msg.sender, proposalId, account.balance);
        } else {
            proposal.opposition += account.balance;     // add opposition (in wei) to proposal (again, no need for safe math)
            emit ProposalOpposed(msg.sender, proposalId, account.balance);
        }
    }

    function support(uint256 proposalId) public { vote(proposalId, true); }     // redirect to generic function (good for UX)

    function oppose(uint256 proposalId) public { vote(proposalId, false); }     // redirect to generic function (good for UX)
}
