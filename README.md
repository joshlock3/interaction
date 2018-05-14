# Interaction

Welcome to your new gem! In this directory, you'll find the files you need to be able to package up your Ruby library into a gem. Put your Ruby code in the file `lib/interaction`. To experiment with that code, run `bin/console` for an interactive prompt.

TODO: Delete this and the text above, and describe your gem

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'interaction'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install interaction

## Usage

### Getting Started
  Your interaction should inherit from Interaction::Base
  ```
    class ThingToDo < Interaction::Base
      #   code
    end
  ```

### Input
The Input object is responsible for ingesting parameters for the interactor and converting hash keys to dot methods.

  `ThingToDo.call(greeting: "Bonjour!")`

  ```
    class ThingToDo < Interaction::Base
      def call
        # input.greeting => "Bonjour!"
      end
    end
  ```

  You get some inputs for free:
  ```
    #   input.inputs_given? => true
    #   input.exceptions => [TypeError]
  ```
  You can add validations for your inputs:
  ```
  coming soon
  ```

### Result
  Your interaction also has a Result object that is responsible for reporting the status and details
  of the action it was initialized on. A Result is a success until it is explicitly invoked to fail.

  ```
    class ThingToDo < Interaction::Base
      def call
        if determine_language(input.greeting)
          result.details = { farewell: farewell_for_greeting(input.greeting) }
        else
          result.fail(error: "Language couldn't be determined.")
        end
      end
    end
  ```


  `thing_to_do = ThingToDo.call(greeting: "Bonjour!")`
  `thing_to_do.details => { farewell: "Au revoir" }`
  `thing_to_do.success? => true`
  `thing_to_do.failure? => false`

### Exceptions
```
coming soon
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/interaction. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the Interaction project’s codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/[USERNAME]/interaction/blob/master/CODE_OF_CONDUCT.md).
