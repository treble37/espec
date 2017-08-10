defprotocol Espec.Comparable do
  @moduledoc """
  This protocol is used for comparing and diffing different date/time representations
  """

  @type granularity :: :years | :months | :weeks | :calendar_weeks | :days |
                       :hours | :minutes | :seconds | :milliseconds | :microseconds |
                       :duration
  @type comparable :: Date.t | DateTime.t
  @type constants :: :epoch | :zero | :distant_past | :distant_future
  @type compare_result :: -1 | 0 | 1 | {:error, term}
  @type diff_result :: integer | {:error, term}

  @doc """
  Get the difference between two date or datetime types.

  You can optionally specify a diff granularity, any of the following:

  - :years
  - :months
  - :calendar_weeks (weeks of the calendar as opposed to actual weeks in terms of days)
  - :weeks
  - :days
  - :hours
  - :minutes
  - :seconds
  - :milliseconds
  - :microseconds (default)
  - :duration

  and the result will be an integer value of those units or a Duration struct.
  The diff value will be negative if `a` comes before `b`, and positive if `a` comes
  after `b`. This behaviour mirrors `compare/3`.
  """
  @spec diff(comparable, comparable, granularity) :: diff_result
  def diff(a, b, granularity \\ :microseconds)
end
