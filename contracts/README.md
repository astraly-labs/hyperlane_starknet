## Getting Started


### Installing Scarb 
You can install Scarb following this [link] (https://docs.swmansion.com/scarb/download)

### Installing Starknet Foundry
To install snforge, you can follow this [link](https://github.com/foundry-rs/starknet-foundry)

### Building
Once installed, you can compile the contracts by executing this command:
```bash
scarb build
```

### Formatting:
To format your code:
```bash
scarb fmt
```

### Testing
Run the tests using snforge:
```bash
snforge test
```

### Integration Tests
To run the integration tests: 
    - Install [Dojo] (https://book.dojoengine.org/getting-started)
    - Install [Foundry] (https://book.getfoundry.sh/getting-started/installation)

Once installed, build the contracts: 
```bash
cd contracts && scarb build
```

Open another terminal, start a new Katana instance: 
```bash
 katana -b 1000 &
 ```

Run evm -> strk messaging test on the first terminal: 
 ```bash
 cd rust && cargo test -- test_mailbox_evm_to_strk
 ```

Once the test passed, kill the katana instance: 
```bash
pkill katana
```

Restart another instance for the second test (strk -> evm): 
```bash
cd rust && cargo test -- test_mailbox_strk_to_evm
 ```