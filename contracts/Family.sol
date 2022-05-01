pragma solidity ^0.4.0;

contract MultiSigWallet {

    address private _owner;
    mapping(address => uint8) private _owners;   // Address is valid/unvalid

    uint constant MIN_SIGNATURES = 2;       // Min required approvals for a transaction to happen
    uint private _transactionIdx;           // Transaction index id, incremented after each transaction

    struct Transaction {
      address from;
      address to;
      uint amount;
      uint8 signatureCount;
      mapping (address => uint8) signatures; // (1 or 0) To check if a person has signed or not
    }

    mapping (uint => Transaction) private _transactions;    // Active transactions
    uint[] private _pendingTransactions;                    // Holds the index of pending transaction(s)

    modifier isOwner() {
        require(msg.sender == _owner);
        _;
    }

    modifier validOwner() {             // Check an address if it is one of the owners
        require(msg.sender == _owner || _owners[msg.sender] == 1);
        _;
    }

    // "event" saves events in a log.
    // Useful to check what happened before
    // Can be accessed from JS implementation
    event DepositFunds(address from, uint amount);
    event TransactionCreated(address from, address to, uint amount, uint transactionId);
    event TransactionCompleted(address from, address to, uint amount, uint transactionId);
    event TransactionSigned(address by, uint transactionId);

    // Constructor
    constructor() public {
        _owner = msg.sender;
    }

    function addOwner(address owner) isOwner public {
        _owners[owner] = 1;
    }

    function removeOwner(address owner) isOwner public {
        _owners[owner] = 0;
    }

    // Add(deposit) money 
    function () public payable {
        emit DepositFunds(msg.sender, msg.value);    // Log that a deposit was made
    }

    // TO DO: We can put limitation to withdrawal for kids here using a modifier
    function withdraw(uint amount) public {
        transferTo(msg.sender, amount);
    }

    function transferTo(address to, uint amount) validOwner public {
        
        require(address(this).balance >= amount);
        uint transactionId = _transactionIdx++;     // Increase the transaction index

        // Initialize a new transaction
        Transaction memory transaction;
        transaction.from = msg.sender;
        transaction.to = to;
        transaction.amount = amount;
        transaction.signatureCount = 0;

        _transactions[transactionId] = transaction;
        _pendingTransactions.push(transactionId);

        emit TransactionCreated(msg.sender, to, amount, transactionId); // Log that a new transaction was created
    }

    // View pending transactions
    function getPendingTransactions() view validOwner public returns (uint[]) {
      return _pendingTransactions;
    }

    // Sign/approve a transaction
    function signTransaction(uint transactionId) validOwner public {

      Transaction storage transaction = _transactions[transactionId];

      require(0x0 != transaction.from);                     // Transaction must exist
      require(msg.sender != transaction.from);              // Creator cannot sign the transaction
      require(transaction.signatures[msg.sender] != 1);     // Cannot sign a transaction more than once

      transaction.signatures[msg.sender] = 1;
      transaction.signatureCount++;

      emit TransactionSigned(msg.sender, transactionId);         // Log that a transaction was signed

      if (transaction.signatureCount >= MIN_SIGNATURES) {
        require(address(this).balance >= transaction.amount);
        transaction.to.transfer(transaction.amount);
        emit TransactionCompleted(transaction.from, transaction.to, transaction.amount, transactionId); // Log that a transaction is completed
        deleteTransaction(transactionId);
      }
    }

    function deleteTransaction(uint transactionId) validOwner  public {
    
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

        delete _pendingTransactions[_pendingTransactions.length - 1];   // Delete the last elements
        _pendingTransactions.length--;                                  // Update
        delete _transactions[transactionId];                            // Deleting from a mapping
    }

    // Retrieve the balance of the contract
    function walletBalance() constant public returns (uint) {
      return address(this).balance;
    }
}