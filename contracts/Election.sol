pragma solidity ^0.4.2;

contract Election {
    string public candidateName;

    constructor () public {
        candidateName = "Candidate 1";
    }

    function setCandidate (string _name) public {
        candidateName = _name;
    }
}
