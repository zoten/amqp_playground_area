# Apa

Simple examples following (and modifying by my own taste) RabbitMQ's [tutorials](https://www.rabbitmq.com/getstarted.html)

## Disclaimer

This is not meant to be production code, not complete one :)
(module organization, resolution, configuration, abstractions, validations, also code linting in more than one point probably), in particular:

 * no worker abstraction
   * hardcoded module resolution
   * "hidden" configuration requirements (e.g. name)
   * repeated code
   * no message abstraction
 * no rabbit configuration abstraction
   * repeated code for setup (may make sense due to different setups)
   * repeated code for user auth
 * no real configuration validation
   * no coherent defaults (some configuration field may have one, some may not)
 * no test here :(

See also the official [disclaimer](#disclaimer)

## Usage

### docker-compose

A `docker-compose.yaml` file is provided for fast bootstrap, usable with the `docker-compose-start.sh` script to setup and run it in daemon mode. However, this script will create a `./data/` folder in the project's directory and try to naively `chmod 777` it. Please adjust this behaviour to your security needs.

``` bash
./docker-compose-start.sh
```

The management UI will be available on [localhost:15672](http://localhost:15672/)
Then you may start any of the given configurations using the scripts described below, or just roll out your own experiment.

### Environment variables

| variable           | description                                | default              |
| ------------------ | ------------------------------------------ | -------------------- |
| CONFIGURATION_PATH | Path from where configuration will be read | `configuration.yaml` |

## Patterns

### "Something that does something"

|               |                                                                          |
| ------------- | ------------------------------------------------------------------------ |
| **script**    | [`./start-1-hello-world.sh`](./start-1-hello-world.sh)                   |
| **file**      | [`configuration-1-hello-world.yaml`](./configuration-1-hello-world.yaml) |
| **reference** | [tutorial](https://www.rabbitmq.com/tutorials/tutorial-one-elixir.html)  |

### Work Queues pattern

|               |                                                                          |
| ------------- | ------------------------------------------------------------------------ |
| **script**    | [`./start-2-work-queues.sh`](./start-2-work-queues.sh)                   |
| **file**      | [`configuration-2-work-queues.yaml`](./configuration-2-work-queues.yaml) |
| **reference** | [tutorial](https://www.rabbitmq.com/tutorials/tutorial-two-elixir.html)  |

### Publish/Subscribe pattern

|               |                                                                                      |
| ------------- | ------------------------------------------------------------------------------------ |
| **script**    | [`./start-3-publish-subscribe.sh`](./start-3-publish-subscribe.sh)                   |
| **file**      | [`configuration-3-publish-subscribe.yaml`](./configuration-3-publish-subscribe.yaml) |
| **reference** | [tutorial](https://www.rabbitmq.com/tutorials/tutorial-three-elixir.html)            |

### Routing pattern

|               |                                                                          |
| ------------- | ------------------------------------------------------------------------ |
| **script**    | [`./start-4-routing.sh`](./start-4-routing.sh)                           |
| **file**      | [`configuration-4-routing.yaml`](./configuration-4-routing.yaml)         |
| **reference** | [tutorial](https://www.rabbitmq.com/tutorials/tutorial-four-elixir.html) |

### Topics pattern

|               |                                                                          |
| ------------- | ------------------------------------------------------------------------ |
| **script**    | [`./start-5-topics.sh`](./start-5-topics.sh)                             |
| **file**      | [`configuration-5-topics`](./configuration-5-topics)                     |
| **reference** | [tutorial](https://www.rabbitmq.com/tutorials/tutorial-five-elixir.html) |

### RPC pattern (example)

|               |                                                                         |
| ------------- | ----------------------------------------------------------------------- |
| **script**    | [`./start-6-rpc.sh`](./start-6-rpc.sh)                                  |
| **file**      | [`configuration-6-rpc`](./configuration-6-rpc)                          |
| **reference** | [tutorial](https://www.rabbitmq.com/tutorials/tutorial-six-elixir.html) |

## Gotchas

### Logged errors parsing messages

Due to usage of the same queues name (in particular in tutorial 1 and 2) you may encounter some initial errors in subsequent calls of different scenarios due to messages enqueued but not yet delivered. Don't worry (or change the queue names if this really bugs you!) :)

## <a name="disclaimer"></a> Production \[Non-\]Suitability Disclaimer

Directly copy-pasted from [RabbitMQ's tutorials page](https://www.rabbitmq.com/tutorials)

 > Please keep in mind that this and other tutorials are, well, tutorials. They demonstrate one new concept at a time and may intentionally oversimplify some things and leave out others. For example topics such as connection management, error handling, connection recovery, concurrency and metric collection are largely omitted for the sake of brevity. Such simplified code should not be considered production ready.
