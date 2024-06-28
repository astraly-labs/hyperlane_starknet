<!-- prettier-ignore-start -->
<!-- markdownlint-disable -->

<!-- ************************************* -->
<!-- *        HEADER WITH LOGO           * -->
<!-- ************************************* -->
<p align="center">
  <img src="assets/logo/logo.png" height="256">
</p>

<h1 align="center">⚡ Hyperlane Starknet ⚡</h1>

<p align="center">
  <strong>A Starknet implementation of Hyperlane</strong>
</p>

<p align="center">
  <a href="https://hyperlane.xyz">https://hyperlane.xyz</a>
</p>

<!-- ************************************* -->
<!-- *        BADGES                     * -->
<!-- ************************************* -->
<div align="center">
<br />


</div>

<!-- ************************************* -->
<!-- *        CONTENTS                   * -->
<!-- ************************************* -->

This repository is an implementation of the Hyperlane protocol for Starknet app-chains.
You can learn more about Hyperlane [here](https://docs.hyperlane.xyz/docs/protocol/protocol-overview).

The implementation guidelines can be found [here](https://docs.hyperlane.xyz/docs/guides/implementation-guide).


## Project structure

### Contracts

The contracts are located in the `contracts/` directory. It's a `scarb` project, so you can use the `scarb` CLI to build it.

It uses `Starknet Foundry` for tests.

See the [contracts README](contracts/README.md) for more information.

### Pre-requisites
- Install Scarb (see [here](https://docs.swmansion.com/scarb/download))
- Install Starknet Foundry (see [here](https://github.com/foundry-rs/starknet-foundry))

### Build

Once installed, you can compile the contracts by executing this command:
```bash
scarb build
```

### Format

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
  - Install [Dojo](https://book.dojoengine.org/getting-started)
  - Install [Foundry](https://book.getfoundry.sh/getting-started/installation)

Once installed, build the contracts: 
```bash
cd contracts && scarb build && cd -
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

## 📖 License

This project is licensed under the **MIT license**. See [LICENSE](LICENSE) for more information.

## Contributors ✨

Thanks goes to these wonderful people ([emoji key](https://allcontributors.org/docs/en/emoji-key)):

<!-- ALL-CONTRIBUTORS-LIST:START - Do not remove or modify this section -->
<!-- prettier-ignore-start -->
<!-- markdownlint-disable -->


<!-- markdownlint-restore -->
<!-- prettier-ignore-end -->

<!-- ALL-CONTRIBUTORS-LIST:END -->

This project follows the [all-contributors](https://github.com/all-contributors/all-contributors) specification. Contributions of any kind welcome!