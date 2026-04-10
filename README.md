# Interaction

A small Ruby gem for the service object / interactor pattern. Every interaction is a class that inherits from `Interaction::Base`, implements `#call`, and returns a `Result` object carrying `success?`, `failure?`, `details`, `error`, and a typed failure `code`.

The gem is deliberately small — the entire library is under 500 lines — and has no runtime dependencies. It stays out of your way: there is no Rails coupling in the core, no forced result shape, no magic. The opinionated parts (input declaration, guards, composition, hooks) are opt-in and composable.

**Core value proposition:** every unit of business logic is a single class with one public entry point, one return type, and a predictable contract. Callers (GraphQL resolvers, controllers, jobs, other interactions) can always inspect `result.success?` and `result.code` without having to wrap calls in `rescue`.

## Installation

Add to your `Gemfile`:

```ruby
gem "interaction"
```

Or, to track the latest from source:

```ruby
gem "interaction", github: "joshlock3/interaction"
```

Then run `bundle install`.

Ruby 3.0 or later is required.

## Quickstart

```ruby
class GreetUser < Interaction::Base
  input :name, String, required: true
  input :enthusiastic, :boolean, default: false

  def call
    greeting = enthusiastic ? "HELLO #{name.upcase}!!!" : "Hi #{name}"
    result.details = { greeting: greeting }
  end
end

result = GreetUser.call(name: "Ada")
result.success?          # => true
result.details[:greeting] # => "Hi Ada"

failed = GreetUser.call
failed.failure?            # => true
failed.code                # => :invalid_input
failed.error               # => "name is required"
failed.failed_with?(:invalid_input) # => true
```

## The `Result` object

Every `Interaction::Base.call(...)` returns an `Interaction::Result`. Results start successful. They become failed exactly when `fail`, `fail_with`, or `fail_from_exception` is called on them (or when the body raises an uncaught exception — see [Exception handling](#exception-handling)).

```ruby
result = SomeInteraction.call(args)

result.success?                  # true unless something failed
result.failure?                  # true if failed
result.details                   # Hash of arbitrary payload
result.error                     # shortcut for result.details[:error]
result.code                      # the failure code symbol, or nil
result.failed_with?(:forbidden)  # true iff failed with that code
```

Set details from inside `#call` via `result.details =` or the failure helpers:

```ruby
def call
  goal = Goal.create!(...)
  result.details = { goal: goal }
end
```

### `fail` vs `fail_with`

There are two ways to mark a result as failed:

```ruby
# Destructive: replaces the entire details hash.
result.fail(error: "Not allowed", code: :forbidden)

# Merging: merges into existing details, preserving other keys.
result.details = { draft: incomplete_record }
result.fail_with(error: "validation failed", code: :invalid_input)
# result.details => { draft: incomplete_record, error: "validation failed", code: :invalid_input }
```

Both accept a `code:` key, which is extracted into `result.code`. Prefer `fail_with` in new code — it's non-destructive, which means you can set preliminary state before knowing whether the interaction will succeed without losing it on failure.

From inside an interaction, the instance method `fail_with` delegates to `result.fail_with` so you can write:

```ruby
def call
  fail_with(error: "Not allowed", code: :forbidden) unless current_user.admin?
  # ...
end
```

## Declaring inputs

Use `input` to declare expected inputs with their type, whether they're required, defaults, and optional coercion:

```ruby
class UpdateUser < Interaction::Base
  input :user_id,      String,  required: true
  input :username,     String,  required: false
  input :current_user, User,    required: true
  input :delete,       :boolean, default: false
  input :target_date,  :date,   required: false, coerce: true

  def call
    # user_id, username, current_user, delete, target_date are all
    # available as instance methods.
    user = User.find(user_id)
    # ...
  end
end
```

Inputs declared with `input` become instance methods. They can be read from inside `#call`, guards, hooks, and private methods. Values are resolved once and cached per call.

**Required vs optional.** `required: true` (the default) means the value must be present and non-blank. Missing or blank required inputs cause the interaction to fail with `code: :invalid_input` before `#call` runs. A default (if any) is applied before the required check, so `input :limit, Integer, required: true, default: 20` never fails for blank input.

**Blank means:** `nil`, or an empty collection (`""`, `[]`, `{}`). Booleans `false` and numeric `0` are NOT blank.

**Defaults** can be values or callables:

```ruby
input :limit, Integer, default: 20
input :at,    :date,   default: -> { Date.today }
```

Callable defaults are re-evaluated on each interaction invocation.

**Coercion** is opt-in per input. Set `coerce: true` to run a small built-in coercion for the declared type:

```ruby
input :count, Integer, default: 0, coerce: true
# "42" → 42, "abc" → "abc" (unchanged on failure)
```

Built-in coercions: `:string`/`String`, `:integer`/`Integer`, `:boolean`, `:date`/`Date`, `:hash`/`Hash`, `:array`/`Array`. Unknown types pass through unchanged. Failed coercions return the original value — validation errors surface through the `required:` check, not coercion.

**Inheritance:** `input` declarations are inherited by subclasses via an `inherited` hook. A subclass can override a parent declaration by redeclaring the same name.

### Legacy `delegate_input` and `require_input`

Pre-3.3 interactions use `delegate_input` for access and `require_input` for presence checks:

```ruby
class Legacy < Interaction::Base
  delegate_input :user_id, :name
  require_input :user_id

  def call
    # user_id, name available; user_id presence-checked
  end
end
```

Both still work and are fully backwards-compatible. `require_input` failures become a failed `Result` (they raise `Interaction::InputError` internally, which `Base.call`'s top-level rescue converts into `result.fail_from_exception`). New code should prefer `input` — it covers the same ground and adds types, defaults, and coercion in one declaration. Mix freely during migration.

## Guards

Guards formalize "bail out early if preconditions aren't met." Declare them with `guard :method_name`; each guard is an instance method that runs in declaration order before `#call`. A guard that calls `fail_with` (or any method that marks the result as failed) halts the chain — no further guards and no body execution.

```ruby
class AddGoal < Interaction::Base
  input :current_user, User, required: true
  input :name,         String, required: true

  guard :must_be_authenticated
  guard :must_be_admin

  def call
    goal = Goal.create!(user: current_user, name: name)
    result.details = { goal: goal }
  end

  private

  def must_be_authenticated
    fail_with(error: "Authentication required", code: :unauthorized) if current_user.nil?
  end

  def must_be_admin
    fail_with(error: "Admin only", code: :forbidden) unless current_user.admin?
  end
end
```

**Guards run AFTER input validation.** So by the time a guard runs, every `input` declared as `required: true` is guaranteed present and non-blank. Guards can focus on business-logic preconditions (authorization, ownership, state) rather than re-checking input presence.

Like inputs, guards are inherited by subclasses.

## Composition with `run`

`run` lets one interaction call another and automatically propagates failure. If the sub-interaction succeeds, `run` returns its `details` hash. If it fails, `run` copies the sub-result's details into the parent (including `code`) and halts execution via `throw :halt_interaction` — the rest of the parent's `#call` never runs.

```ruby
class CreateGoalAndFollow < Interaction::Base
  input :user, User,   required: true
  input :name, String, required: true

  def call
    goal_details = run GoalTracking::AddGoal, user: user, name: name
    # if AddGoal failed, we never got here; parent already failed with the same code

    run Social::FollowGoal, user: user, goal: goal_details[:goal]

    result.details = { goal: goal_details[:goal] }
  end
end
```

`run` is a non-local exit — there's no exception overhead. The `throw :halt_interaction` is caught in `Base.call`. Nested composition (child runs grandchild) propagates failures all the way up.

This makes it cheap to break a large interaction into smaller, independently-testable ones. You no longer need to write manual `return result.fail(...) if sub_result.failure?` boilerplate for every sub-call.

## Before/after hooks

Class-level `before_call` and `after_call` hooks run around `#call`. They accept method names (or multiple names per declaration):

```ruby
class AddGoal < Interaction::Base
  input :user_id, String, required: true

  before_call :log_start
  after_call  :enqueue_gamification

  def call
    goal = Goal.create!(...)
    result.details = { goal: goal }
  end

  private

  def log_start
    Rails.logger.info("AddGoal starting user=#{user_id}")
  end

  def enqueue_gamification
    return if result.failure?
    enqueue Gamification::CreateGoalActionJob, user_id
  end
end
```

**`after_call` hooks always run**, on both success and failure. Check `result.failure?` inside the hook to skip work when the interaction failed.

Hooks are inherited by subclasses. Parent hooks run before child hooks for `before_call`; both run for `after_call`.

## Enqueueing jobs

The `enqueue` helper wraps ActiveJob (or any job class exposing `perform_now` / `perform_later`). In Rails test and development environments it runs the job synchronously; in production it calls `perform_later`. This removes the per-interaction `Rails.env.test? ? :perform_now : :perform_later` conditional.

```ruby
def call
  goal = Goal.create!(...)
  enqueue Gamification::CreateGoalActionJob, goal.user_id
  result.details = { goal: goal }
end
```

The behavior is driven by `Interaction.configuration.enqueue_synchronously?`. Override with a callable or literal boolean:

```ruby
Interaction.configure do |c|
  c.enqueue_synchronously = -> { ENV["SYNC_JOBS"] == "true" }
end
```

Default: `Rails.env.test? || Rails.env.development?` when Rails is loaded, otherwise `false`.

## Failure codes

`Interaction::Codes` lists the conventional failure symbols:

```ruby
Interaction::Codes::INVALID_INPUT  # :invalid_input
Interaction::Codes::UNAUTHORIZED   # :unauthorized
Interaction::Codes::FORBIDDEN      # :forbidden
Interaction::Codes::NOT_FOUND      # :not_found
Interaction::Codes::CONFLICT       # :conflict
Interaction::Codes::SERVER_ERROR   # :server_error
Interaction::Codes::ALL            # [frozen array of all the above]
```

These are **recommendations, not enforced.** Any symbol works as a failure code. Using these constants avoids typos and gives callers a shared vocabulary for differentiating failures.

Callers can pattern-match on the code:

```ruby
result = SomeInteraction.call(args)

case
when result.success?
  render json: result.details
when result.failed_with?(:not_found)
  head :not_found
when result.failed_with?(:forbidden)
  head :forbidden
when result.failed_with?(:invalid_input)
  render json: { error: result.error }, status: :unprocessable_entity
else
  render json: { error: "Server error" }, status: :internal_server_error
end
```

## Exception handling

`Base.call` wraps the body of each interaction in a rescue that captures any `StandardError`, reports it through the configured `on_error` handler, and turns it into a failed `Result` with `code: :server_error`:

```ruby
result = SomeInteraction.call(args)  # no need to rescue — exceptions become failures

result.failed_with?(:server_error)   # true if an exception was rescued
result.error                         # the exception message
```

The default `on_error` handler:

1. Sends the exception to Sentry if Sentry is loaded and initialized
2. Logs to `Rails.logger.error` if Rails is loaded
3. Writes to stderr

Override the default by setting a custom handler:

```ruby
Interaction.configure do |c|
  c.on_error = ->(error, class_name:, tags:) {
    MyErrorTracker.notify(error, tags: tags, context: class_name)
  }
end
```

Precedence for `code:` on exception paths: `:server_error` (default) < caller-supplied `code:` < the instance's `custom_exception_detail`. Interactions that want a more specific code on the exception path can set `self.custom_exception_detail = { code: :conflict }` at the start of `#call`.

## Testing with RSpec

The gem ships opt-in RSpec matchers. Require them from your `spec_helper.rb`:

```ruby
# spec/spec_helper.rb
require "interaction/rspec"
```

Then use them in your specs:

```ruby
RSpec.describe GoalTracking::AddGoal do
  let(:user) { create(:user) }

  it "creates a goal" do
    result = described_class.call(user_id: user.public_id, name: "run 5k", current_user: user)

    expect(result).to be_a_successful_interaction
    expect(result).to have_interaction_details(goal: an_instance_of(Goal))
  end

  it "rejects unauthenticated requests" do
    result = described_class.call(name: "run 5k")
    expect(result).to have_failed_with(:invalid_input)
  end

  it "rejects non-admins with a forbidden code" do
    result = described_class.call(user_id: user.public_id, name: "run 5k", current_user: non_admin)
    expect(result).to have_failed_with(:forbidden)
  end

  it "includes the user-facing error message" do
    result = described_class.call(name: "run 5k", current_user: nil)
    expect(result).to have_failed_with("Authentication required")
  end
end
```

**Matchers:**

- `be_a_successful_interaction` — passes if `result.success?`
- `have_failed_with(sym_or_string)` — with a Symbol, checks `result.code == sym`; with a String, checks that `result.error` includes the substring
- `have_interaction_details(**kwargs)` — checks that each key/value is present in `result.details`; supports composable matchers like `an_instance_of(Goal)` and `a_hash_including(...)`

Matchers require RSpec to be loaded. If you don't use RSpec, don't require `interaction/rspec`.

## Configuration

```ruby
Interaction.configure do |c|
  # Where exceptions get reported (default: Sentry + Rails.logger + stderr).
  c.on_error = ->(error, class_name:, tags:) { ... }

  # Whether enqueue runs jobs synchronously. Accepts a callable or a boolean.
  c.enqueue_synchronously = -> { Rails.env.test? || Rails.env.development? }
end
```

Typically you'd drop this into `config/initializers/interaction.rb` in a Rails app.

## Philosophy

Why this gem over something like `ActiveInteraction`?

- **Smaller surface area.** Under 500 lines for the whole library. No Dry-Types, no filters, no I18n, no state machine. Fast to learn, fast to audit, fast to modify.
- **Single return contract.** Every interaction returns a `Result`. Callers always know what to check. No exceptions leak out (unless you deliberately propagate them).
- **Composable, not magical.** Inputs, guards, composition, and hooks are each their own small module. You can include any subset; you can inspect what's happening.
- **Failure codes as a first-class signal.** `code:` is a machine-readable failure reason that callers (GraphQL, controllers, other interactions) can differentiate without string matching.
- **No Rails coupling in the core.** `Base`, `Result`, and `Input` don't require Rails. The `enqueue` helper and the default `on_error` handler *use* Rails if it's loaded but don't require it.

If you need rich type coercion, ActiveModel-style validations with error arrays, or explicit input/output record definitions, you may prefer `ActiveInteraction`. This gem is optimized for small, focused interactions with a predictable shape.

## Method resolution order

For interactions that use the full DSL, the call flow is:

```
Base.call(args)
  └─ catch(:halt_interaction)
       ├─ before_call_hooks run in declaration order
       └─ instance.call:
            1. InputDsl::InstanceMethods#call  — validates inputs, fails with :invalid_input if any required missing
            2. Guard::InstanceMethods#call      — runs guards in declaration order, halts on first failure
            3. your #call body                  — business logic
       (exception here → rescued, converted to fail_from_exception)
  └─ after_call_hooks run (even on failure)
  └─ return result
```

`run` inside `#call` throws `:halt_interaction` on sub-failure, skipping the rest of the body but still running `after_call` hooks.

## Development

```bash
bin/setup            # install dependencies
bundle exec rspec    # run tests
bundle exec standardrb  # lint
```

## Contributing

Bug reports and pull requests are welcome on GitHub at [joshlock3/interaction](https://github.com/joshlock3/interaction).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
