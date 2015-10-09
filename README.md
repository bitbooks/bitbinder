# Bitbinder

Bitbinder is a tiny Sinatra application, whos only job is to create an
endpoint for other services to trigger a middleman ([Franklin](https://github.com/bryanbraun/franklin)) build.

# Deploy
Set your environment variables:
SECRET_KEY          # Key for decrypting user Oauth Tokens
BITBOOKS_PASS       # Password for secure API requests between bitbooks & bitbinder.

Turn on the endpoint by running the file:
```bash
bundle exec rackup
```

Based on [Ben Balter](https://github.com/benbalter)'s [copy-to](https://github.com/benbalter/copy-to). Thanks Ben!
