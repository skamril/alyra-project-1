// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.17;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/Ownable.sol";

contract Voting is Ownable {

    struct Voter {
        bool isRegistered;
        bool hasVoted;
        uint votedProposalId;
    }

    struct Proposal {
        string description;
        uint voteCount;
    }

    enum WorkflowStatus {
        RegisteringVoters,
        ProposalsRegistrationStarted,
        ProposalsRegistrationEnded,
        VotingSessionStarted,
        VotingSessionEnded,
        VotesTallied
    }

    event VoterRegistered(address voterAddress); 
    event WorkflowStatusChange(WorkflowStatus previousStatus, WorkflowStatus newStatus);
    event ProposalRegistered(uint proposalId);
    event Voted (address voter, uint proposalId);

    mapping(address => Voter) private voters;
    Proposal[] private proposals;
    address[] private voterAddresses;
    WorkflowStatus private currentStatus = WorkflowStatus.RegisteringVoters;

    modifier isVoter {
        require(voters[msg.sender].isRegistered == true, "Voter not registered");
        _;
    }

    /**
     * @dev Register a voter.
     */
    function registerVoter(address _voterAdress) external onlyOwner {
        require(currentStatus == WorkflowStatus.RegisteringVoters, "Not able to register");
        require(voters[_voterAdress].isRegistered == false, "Voter already registered");
        
        voters[_voterAdress] = Voter(true, false, 0);
        voterAddresses.push(_voterAdress);

        emit VoterRegistered(_voterAdress);
    }

    /**
     * @dev Register a proposal.
     */
    function registerProposal(string memory description) external isVoter {
        require(currentStatus == WorkflowStatus.ProposalsRegistrationStarted, "Proposals registration not open");

        for (uint i = 0; i < proposals.length; i++) {
          if (keccak256(abi.encodePacked(proposals[i].description)) == keccak256(abi.encodePacked(description))) {
              revert("Proposal already added");
          }
        } 
        proposals.push(Proposal(description, 0));

        emit ProposalRegistered(proposals.length - 1);
    }

    /**
     * @dev Vote for a proposal.
     */
    function voteForProposal(uint index) external isVoter {
        require(currentStatus == WorkflowStatus.VotingSessionStarted, "Vote session not open");
        require(voters[msg.sender].hasVoted == false, "Voter has already voted");
        require(index < proposals.length, "Proposal not exist");

        voters[msg.sender].hasVoted = true;
        voters[msg.sender].votedProposalId = index;

        proposals[index].voteCount = proposals[index].voteCount + 1;

        emit Voted(msg.sender, index);
    }

    /**
     * @dev Get the proposal winner of votes.
     */
    function getWinner() external view returns (string memory proposalWinner) {
        require(currentStatus == WorkflowStatus.VotesTallied, "Votes not alerady tallied");
        require(_hasEquality() == false, "There is an equality, votes must be restart");

        uint maxProposalVotes = _getMaxProposalVotes();

        for (uint i = 0; i < proposals.length; i++) {
          if (proposals[i].voteCount == maxProposalVotes) {
              return proposals[i].description;
          }
        } 
    }

    /**
     * @dev Start proposals registration.
     */
    function startProposalsRegistration() external onlyOwner {
        _updateStatus(
            WorkflowStatus.ProposalsRegistrationStarted, 
            "Proposals registration already started", 
            "Not able to start the proposals registration"
        );
    }

    /**
     * @dev End proposals registration. 
     */
    function endProposalsRegistration() external onlyOwner {
        require (proposals.length > 0, "No proposals added");

       _updateStatus(
            WorkflowStatus.ProposalsRegistrationEnded, 
            "Proposals registration already ended", 
            "Not able to end the proposals registration"
        );
    }

    /**
     * @dev Start voting session.
     */
    function startVotingSession() external onlyOwner {
        _updateStatus(
            WorkflowStatus.VotingSessionStarted, 
            "Voting session already started", 
            "Not able to start the voting session"
        );
    }
    
    /**
     * @dev End voting session.
     */
    function endVotingSession() external onlyOwner {
        _updateStatus(
            WorkflowStatus.VotingSessionEnded, 
            "Voting session already ended", 
            "Not able to end the voting session"
        );
    }

    /**
     * @dev Indicate that vote tallied.
     */
    function voteTallied() external onlyOwner {
        _updateStatus(
            WorkflowStatus.VotesTallied, 
            "Votes already tallied", 
            "Not able to tally votes"
        );
    }

    /**
     * @dev Reset the workflow for the votes.
     */
    function reset() external onlyOwner {
        for (uint i = 0; i < voterAddresses.length; i++) {
            if (voters[voterAddresses[i]].isRegistered) {
                voters[voterAddresses[i]] = Voter(false, false, 0);
            }
        } 

        delete voterAddresses;
        delete proposals;

        _forceUpdateStatus(WorkflowStatus.RegisteringVoters);
    }

    /**
     * @dev Get the max proposal votes value.
     */
    function _getMaxProposalVotes() internal view returns (uint) {
        uint max = 0;
        
        for (uint i = 0; i < proposals.length; i++) {
          if (proposals[i].voteCount > max) {
              max = proposals[i].voteCount;
          }
        } 

        return max;
    }

    /**
     * @dev Check if there is an equality in the votes.
     */
    function _hasEquality() internal view returns (bool) {
        uint maxProposalVotes = _getMaxProposalVotes();
        bool proposalFounded = false;

        for (uint i = 0; i < proposals.length; i++) {
          if (proposals[i].voteCount == maxProposalVotes) {
              if (proposalFounded) {
                  return true;
              }
              proposalFounded == true;
          } 
        } 

        return false;
    }

    /**
     * @dev Update the workflow status.
     */
    function _updateStatus(WorkflowStatus newStatus, string memory alreadyErr, string memory notAbleErr) internal onlyOwner {
        require(currentStatus != newStatus, alreadyErr);

        if (newStatus == WorkflowStatus.RegisteringVoters) {
            require(currentStatus == WorkflowStatus.VotesTallied, notAbleErr);
        } else {
            require(uint8(currentStatus) == uint8(newStatus) - 1, notAbleErr);
        }

        _forceUpdateStatus(newStatus);
    }

    /**
     * @dev Update the workflow status without verification.
     */
    function _forceUpdateStatus(WorkflowStatus newStatus) internal onlyOwner {
        WorkflowStatus prevStatus = currentStatus;
        currentStatus = newStatus; 

        emit WorkflowStatusChange(prevStatus, newStatus);
    }
}