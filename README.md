# Universal Permit2 Adapter

Permit2 by Uniswap is an amazing development that will revolutionize the UX in Web3. However, it can be hard to migrate
existing contracts to use this new way of transferring tokens.

To help in those cases, we've built the Universal Permit2 Adapter. It's basically an adapter that can be used to give
Permit2 capabilities to existing contracts, without having to to re-deploy.

If you'd like to interact with these contracts, we suggest you use our
[SDK](https://github.com/Mean-Finance/sdk/tree/main/src/services/permit2) that already handles most of the complexities
around it.

## Usage

This is a list of the most frequently needed commands.

### Build

Build the contracts:

```sh
$ forge build
```

### Clean

Delete the build artifacts and cache directories:

```sh
$ forge clean
```

### Compile

Compile the contracts:

```sh
$ forge build
```

### Coverage

Get a test coverage report:

```sh
$ forge coverage
```

### Format

Format the contracts:

```sh
$ forge fmt
```

### Gas Usage

Get a gas report:

```sh
$ forge test --gas-report
```

### Lint

Lint the contracts:

```sh
$ pnpm lint
```

### Test

Run the tests:

```sh
$ forge test
```

## Audit

This code has been audited by Omniscia.io. You can find the report
[here](https://omniscia.io/reports/mean-finance-permit2-adapter-64ad40c224448c00148ee2f9/).

## License

This project is licensed under MIT.
