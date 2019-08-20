defmodule Ballast.PeriodicTask do
  @moduledoc """

  ## Examples
  five_minutes = 1000 * 60 * 5
  slow_task = %Ballast.PeriodicTask{mfa: {IO, :puts, ["Slow task"]}, interval: five_minutes, jitter: 0.5}
  Ballast.PeriodicTask.register(slow_task)
  quick_task = %Ballast.PeriodicTask{mfa: {IO, :puts, ["Quick task"]}, interval: 1000}
  Ballast.PeriodicTask.register(quick_task)

  goodbye_task = %Ballast.PeriodicTask{mfa: {IO, :puts, [%{}]}, interval: 1000}
  Ballast.PeriodicTask.register(goodbye_task)
  """

  use GenServer
  use Bitwise
  require Logger

  # interval ms
  @type t :: %__MODULE__{
          mfa: {atom(), atom(), list(any())},
          interval: pos_integer(),
          jitter: float(),
          next: nil | pos_integer(),
          id: binary()
        }

  defstruct mfa: nil, interval: 1000, jitter: 0.0, next: nil, id: nil

  def start_link(tasks), do: GenServer.start_link(__MODULE__, tasks, name: __MODULE__)

  def list(), do: GenServer.call(__MODULE__, :list)

  def register(%__MODULE__{id: id} = task) when is_nil(id), do: task |> gen_id |> register
  def register(%__MODULE__{} = task), do: GenServer.cast(__MODULE__, {:register, task})

  @impl true
  def init(tasks \\ %{}), do: {:ok, tasks}

  @impl true
  def handle_call(:list, _from, state), do: {:reply, state, state}

  @impl true
  def handle_cast({:register, %__MODULE__{id: id} = task}, state) do
    task_w_schedule = schedule_run(task)
    state = Map.put(state, id, task_w_schedule)

    {:noreply, state}
  end

  @impl true
  def handle_info({:run, %__MODULE__{id: id, mfa: {m, f, a}} = task}, state) do
    Task.async(fn ->
      case apply(m, f, a) do
        :ok ->
          Logger.info("Job #{id} succeeded")

        {:ok, _result} ->
          Logger.info("Job #{id} succeeded")

        :error ->
          Logger.error("Job #{id} failed")

        {:error, _reason} ->
          Logger.error("Job #{id} failed")
      end

      task
    end)

    {:noreply, state}
  end

  @impl true
  def handle_info({_task_ref, %__MODULE__{id: id} = task}, state) do
    # Reschedule
    task_w_schedule = schedule_run(task)
    state = Map.put(state, id, task_w_schedule)

    {:noreply, state}
  end

  @impl true
  def handle_info(msg, state) do
    Logger.warn("Unhandled #{inspect(msg)}")
    {:noreply, state}
  end

  defp schedule_run(%__MODULE__{} = old_task) do
    next_task = calculate_interval(old_task)

    Logger.info("Next task #{next_task.id} in: #{next_task.next} ms")
    Process.send_after(self(), {:run, next_task}, next_task.next)
  end

  defp calculate_interval(%__MODULE__{interval: int, jitter: jitter} = task) do
    jitter = :rand.uniform() * int * jitter
    next = round(int + jitter)

    %__MODULE__{task | next: next}
  end

  defp gen_id(%__MODULE__{} = task) do
    id = System.unique_integer([:positive])
    %__MODULE__{task | id: "job-#{id}"}
  end
end
