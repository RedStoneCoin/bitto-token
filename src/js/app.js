App = {
  web3Provider: null,
  contracts: {},
  address: "0x5929590099b12ad2c63cb1b8812de9da2c707c3b",

  init: function() {
    return App.initWeb3();
  },

  initWeb3: function() {
    // Initialize web3 and set the provider to the testRPC.
    if (typeof web3 !== 'undefined') {
      App.web3Provider = web3.currentProvider;
      web3 = new Web3(web3.currentProvider);
    } else {
      // set the provider you want from Web3.providers
      App.web3Provider = new Web3.providers.HttpProvider('http://127.0.0.1:9545');
      web3 = new Web3(App.web3Provider);
    }

    return App.initContract();
  },

  initContract: function() {
    $.getJSON('BITTOToken.json', function(data) {
      // Get the necessary contract artifact file and instantiate it with truffle-contract.
      var abi = data.abi;
      var contract_class = web3.eth.contract(abi);
      App.contracts.Token = contract_class.at(App.address);

      // Use our contract to retieve and mark the adopted pets.
      return App.getBalances();
    });

    return App.bindEvents();
  },

  bindEvents: function() {
    $(document).on('click', '#transferButton', App.handleTransfer);
  },

  handleTransfer: function(event) {
    event.preventDefault();

    var lines = $('#holders').val().split("\n");
    var recipients = [];
    var values = [];
    lines.forEach(element => {
      var data = element.split('\t');
      recipients.push(data[1]);
      values.push(web3.toWei(data[2], "ether"));
    });

    App.contracts.Token.batchTransfer(recipients, values, function(error, result) {
      if (error) {
        console.log(error);
        $('#console').html(error);
      } else {
        alert('Token dropped successfully!');
        $('#console').html(`Token dropped to ${recipients.length} accounts`);
      }
    });
  },

  getBalances: function() {
    console.log('Getting balances...');

    web3.eth.getAccounts(function(error, accounts) {
      if (error) {
        console.log(error);
      }
      var account = accounts[0];
      $('#account').text(account);
      console.log(account);
      App.contracts.Token.balanceOf(account, function(error, result) {
        if (error) console.log(error);
        else $('#TTBalance').text(web3.fromWei(result, "ether"));
      });
    });
  }

};

$(function() {
  $(window).load(function() {
    App.init();
  });
});
