// Multi signature Family Wallet
// Author(s):
//          - Mustafa Gokturk Yandim
//
// Sabanci University - 2022

pragma solidity ^0.4.0;

contract MultiSigWallet {

    // ##############################################################################################################################
    // DEFINITIONS

    address private _owner;                                     // Address of the contract deployer
    mapping(address => uint8) private _owners;                  // Parent/Owners address list / Mapped to uint8 (1 or 0) to hold active/inactive owner wallets
    mapping(address => uint8) private _children;                // Children address list / Mapped to uint8 (1 or 0) to hold active/inactive child wallets

    uint constant MIN_SIGNATURES = 2;                           // Min required approvals for a transaction to happen
    uint private _transactionIdx;                               // Transaction index id, incremented after each transaction

    // Struct to hold information about a transaction
    struct Transaction {
      address from;
      address to;
      uint amount;
      uint8 signatureCount;
      mapping (address => uint8) signatures;                    // (1 or 0) To check if a person has signed or not
    }

    mapping (uint => Transaction) private _transactions;                // Active transactions
    uint[] private _pendingTransactions;                                // Holds the index of pending transaction(s)


    // ##############################################################################################################################
    // EVENTS (LOGGING)
    // :    "event" saves events in a log.
    // :    Useful to check what happened before
    // :    Logs can be accessed in WEB3 javascript implementation

    event DepositFunds(address from, uint amount);
    event TransactionCreated(address from, address to, uint amount, uint transactionId);
    event TransactionCompleted(address from, address to, uint amount, uint transactionId);
    event TransactionSigned(address by, uint transactionId);
    event childAdded(address owner, address child);


    // ##############################################################################################################################
    // CONTRACT CONTROL

    // Constructor
    constructor() public {
        _owner = msg.sender;
    }

    // -- MODIFIER:
    // Check the address if it is one of owners/parents
    // Accessibility: only Owners/Parents 
    modifier isOwner() {                                                                         
        require(msg.sender == _owner || _owners[msg.sender] == 1);    
        _;
    }

    function addOwner(address owner) isOwner public {
        _owners[owner] = 1;
    }

    function removeOwner(address owner) isOwner public {
        _owners[owner] = 0;
    }

    // Add a new child wallet 
    function addChild(address child) isOwner public {
        _children[child] = 1;
        emit childAdded(msg.sender,child);                                                      // Log that a new child was added
    }

    // Remove a child wallet 
    function removeChild (address child) isOwner public {
        _children[child] = 0;
    }


    // ##############################################################################################################################
    // TRANSACTIONS

    // Add(deposit) money to contract
    function () public payable {
        emit DepositFunds(msg.sender, msg.value);                                   // Log that a deposit was made
    }

    // TO DO: We can put limitation to withdrawal for kids here using a modifier
    function withdraw(uint amount) public {
        transferTo(msg.sender, amount);
    }

    // -- MODIFIER:
    // Check the address if it is one of owners or children
    // Accessibility: Owners/Parents and Children
    modifier validUser() {                                                                         
        require(msg.sender == _owner || _owners[msg.sender] == 1 || _children[msg.sender] == 1);    
        _;
    }

    // Transfer from contract balance to a given address
    function transferTo(address to, uint amount) validUser public {

        // TO DO: We can put limitation to transfer for kids here using a modifier
        
        require(address(this).balance >= amount);
        uint transactionId = _transactionIdx++;                                     // Increase the transaction index

        // Initialize a new transaction
        Transaction memory transaction;
        transaction.from = msg.sender;
        transaction.to = to;
        transaction.amount = amount;

        // Sign the transaction (+1) if the caller is an owner
        if (msg.sender == _owner || _owners[msg.sender] == 1){
            transaction.signatureCount = 1;
        } else {    // Children can not sign a transaction themselves
            transaction.signatureCount = 0;
        }

        _transactions[transactionId] = transaction;
        _pendingTransactions.push(transactionId);

        emit TransactionCreated(msg.sender, to, amount, transactionId);             // Log that a new transaction was created
    }


    // Sign/approve a transaction
    function signTransaction(uint transactionId) isOwner public {

      Transaction storage transaction = _transactions[transactionId];

      require(0x0 != transaction.from);                                     // Transaction must exist
      require(msg.sender != transaction.from);                              // Creator cannot sign the transaction
      require(transaction.signatures[msg.sender] != 1);                     // Cannot sign a transaction more than once

      transaction.signatures[msg.sender] = 1;
      transaction.signatureCount++;

      emit TransactionSigned(msg.sender, transactionId);                    // Log that a transaction was signed

      if (transaction.signatureCount >= MIN_SIGNATURES) {
        require(address(this).balance >= transaction.amount);
        transaction.to.transfer(transaction.amount);
        emit TransactionCompleted(transaction.from, transaction.to, transaction.amount, transactionId); // Log that a transaction is completed
        deleteTransaction(transactionId);
      }
    }

    function deleteTransaction(uint transactionId) validUser public {
    
        uint8 replace = 0;

        // We cannot simply delete an index in dynamic array in solidity :(
        // We need to loop the array, delete the index and reorder the remaining elements
        for(uint i = 0; i < _pendingTransactions.length; i++) {
            if (1 == replace) {
            _pendingTransactions[i-1] = _pendingTransactions[i];
            } else if (transactionId == _pendingTransactions[i]) {
            replace = 1;
            }
        }

        assert(replace == 1);                                                   // Protection when replace = 0
        delete _pendingTransactions[_pendingTransactions.length - 1];           // Delete the last elements
        _pendingTransactions.length--;                                          // Update
        delete _transactions[transactionId];                                    // Deleting from a mapping
    }

    // ##############################################################################################################################
    // VIEW FUNCTIONS

    // Retrieve the balance of the contract
    function walletBalance() constant public returns (uint) {
      return address(this).balance;
    }

    // View pending transactions
    function getPendingTransactions() view isOwner public returns (uint[]) {
      return _pendingTransactions;
    }
}