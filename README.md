# Claryence

A Rails application built with Jumpstart Pro.

## Requirements

You'll need the following installed to run the template successfully:

* Ruby 3.2+
* PostgreSQL 12+ (can be switched to SQLite or MySQL)
* Libvips or Imagemagick

Optionally, the [Stripe CLI](https://docs.stripe.com/stripe-cli) to sync webhooks in development.

## Initial Setup

Run `bin/setup` to install Ruby and JavaScript dependencies and setup your database.

```bash
bin/setup
```

## Running Claryence

To run your application, you'll use the `bin/dev` command:

```bash
bin/dev
```

This starts up Overmind running the processes defined in `Procfile.dev`. We've configured this to run the Rails server, CSS bundling, and JS bundling out of the box. You can add background workers like Sidekiq, the Stripe CLI, etc to have them run at the same time.

#### Running on Windows

See the [Installation docs](https://jumpstartrails.com/docs/installation#windows)

#### Running with Docker or Docker Compose

See the [Installation docs](https://jumpstartrails.com/docs/installation#docker)

## Development

This application is built with [Jumpstart Pro](https://jumpstartrails.com) for Rails.
# claryence
