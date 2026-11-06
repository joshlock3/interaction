# Changelog

## 4.0.0

### Breaking

- **`run` halts with an exception.** It raises `Interaction::Halt` (an `::Exception`, not a `StandardError`) instead of `throw :halt_interaction`. Since Rails 7.1, a `throw` out of a transaction block commits the transaction. A bare `rescue` in `#call` no longer swallows the halt.
- **Unexpected exceptions get a generic message.** `result.error` is `config.exception_message` (default `"Something went wrong"`), not the exception's text. The exception still goes to `on_error`.
- **`enqueue` waits for commit.** Jobs run through `config.after_commit` (default `ActiveRecord.after_all_transactions_commit`). A job enqueued inside a transaction runs after the outermost commit, and is dropped on rollback.
- **`fail_from_exception` merges.** It keeps details set before the exception instead of replacing them.
- **Reserved input names raise.** `input :result` (and others that would shadow the interaction's own methods) raises `ArgumentError`.
- **Removed:** the `before_call` / `after_call` hooks, `require_input` and `InputError`.

### Added

- `transactional`: runs the interaction in `config.transaction` (default `ActiveRecord::Base.transaction(requires_new: true)`). Rolls back on an exception, a halted `run` or a failed result. A body that raises `ActiveRecord::Rollback` (swallowed by ActiveRecord) fails with `:server_error` instead of reporting success.
- `.call!`: raises `Interaction::Failure` on failure. Inside another interaction, it propagates as an unreported failure.
- `config.rescue_from(ErrorClass, code:, message:)`: maps expected exceptions to failure codes without reporting them.
- The `on_error` handler gets a `context:` that omits input values (input names, record references, value class names; the exception message is not scrubbed). Handlers without a `context:` keyword are called without it.
- `input ..., strict: true` and `config.strict_inputs`: checks a present value against its declared type after coercion.
- `Interaction::Codes::RATE_LIMITED`.
- `run_interaction`: an alias for `run`.

### Deprecated

- `delegate_input` and `result.fail`. Use `input` and `fail_with`.

### Upgrading from 3.x

1. Search `#call` bodies for `catch(:halt_interaction)` or a bare `rescue` that relied on swallowing a `run` halt.
2. Check client code and specs that match on the raw exception text in `result.error`. Use `rescue_from` for exceptions whose message is meant for users, such as `ActiveRecord::RecordInvalid`.
3. Replace `require_input :x` with `input :x`, and the hooks with explicit calls in `#call`.
4. Specs that assert a job ran inside an open transaction (for example with `use_transactional_fixtures`) still pass. Savepoint commits fire after-commit callbacks, and so does code with no transaction open.
