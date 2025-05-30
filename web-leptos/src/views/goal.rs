use leptos::prelude::*;
use leptos_router::{hooks::use_params, params::Params};
use shared::GoalStatus;

use crate::components::{Header, Main, H2};
use crate::hooks::use_core;
use shared::Event;

#[component]
pub fn Goal() -> impl IntoView {
    let params = use_params::<GoalParams>();
    let (view, _) = use_core(Event::Nothing);

    let goal = move || {
        let params = params.get().ok()?;
        let goal_id = params.id.unwrap_or_default();
        view.get().goals.into_iter().find(|g| g.id == goal_id)
    };

    view! {
        {move || {
            if let Some(goal) = goal() {
                view! {
                    <Header title=format!("Goal: {}", goal.name) />
                    <Main>
                        <div class="space-y-6">
                            <div>
                                <H2 text="Description".to_string() />
                                <p class="text-gray-700">
                                    {goal
                                        .description
                                        .unwrap_or_else(|| "No description".to_string())}
                                </p>
                            </div>

                            <div>
                                <H2 text="Status".to_string() />
                                <p class="text-gray-700">
                                    {match goal.status {
                                        GoalStatus::NotStarted => "Not Started",
                                        GoalStatus::InProgress => "In Progress",
                                        GoalStatus::Completed => "Completed",
                                    }}
                                </p>
                            </div>

                            <div>
                                <H2 text="Dates".to_string() />
                                <div class="grid grid-cols-2 gap-4">
                                    <div>
                                        <p class="font-medium">Start Date</p>
                                        <p class="text-gray-700">
                                            {goal.start_date.unwrap_or_else(|| "Not set".to_string())}
                                        </p>
                                    </div>
                                    <div>
                                        <p class="font-medium">Target Date</p>
                                        <p class="text-gray-700">
                                            {goal.target_date.unwrap_or_else(|| "Not set".to_string())}
                                        </p>
                                    </div>
                                </div>
                            </div>

                            <div>
                                <H2 text="Tempo Target".to_string() />
                                <p class="text-gray-700">
                                    {if let Some(tempo) = goal.tempo_target {
                                        format!("{} BPM", tempo)
                                    } else {
                                        "No tempo target set".to_string()
                                    }}
                                </p>
                            </div>

                            <div>
                                <H2 text="Associated Exercises".to_string() />
                                <div class="mt-4 space-y-4">
                                    {move || {
                                        view.get()
                                            .exercises
                                            .into_iter()
                                            .filter(|exercise| goal.exercise_ids.contains(&exercise.id))
                                            .map(|exercise| {
                                                view! {
                                                    <div class="flex items-center gap-2">
                                                        <svg
                                                            xmlns="http://www.w3.org/2000/svg"
                                                            class="size-5 text-gray-400"
                                                            fill="none"
                                                            viewBox="0 0 24 24"
                                                            stroke="currentColor"
                                                            stroke-width="2"
                                                        >
                                                            <path
                                                                stroke-linecap="round"
                                                                stroke-linejoin="round"
                                                                d="M9 12.75L11.25 15 15 9.75M21 12a9 9 0 11-18 0 9 9 0 0118 0z"
                                                            />
                                                        </svg>
                                                        <span class="text-gray-700">{exercise.name}</span>
                                                    </div>
                                                }
                                            })
                                            .collect::<Vec<_>>()
                                    }}
                                </div>
                            </div>
                        </div>
                    </Main>
                }
                    .into_view()
            } else {
                view! {
                    <Header title="Goal Not Found".to_string() />
                    <Main>
                        <p class="text-gray-700">"We couldn't find that goal"</p>
                    </Main>
                }
                    .into_view()
            }
        }}
    }
}

#[derive(Params, PartialEq, Clone)]
struct GoalParams {
    id: Option<String>,
}
