use leptos::prelude::*;
use leptos_router::{hooks::use_params, params::Params};
use shared::Status;

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
                                        .unwrap_or_else(|| "No description provided".to_string())}
                                </p>
                            </div>

                            <div>
                                <H2 text="Status".to_string() />
                                <p class="text-gray-700">
                                    {match goal.status {
                                        Status::NotStarted => "Not Started",
                                        Status::InProgress => "In Progress",
                                        Status::Completed => "Completed",
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
                                <p>TODO</p>
                            </div>
                        </div>
                    </Main>
                }
                    .into_view()
            } else {
                view! {
                    <Header title="Goal Not Found".to_string() />
                    <Main>
                        <p class="text-gray-700">The requested goal could not be found.</p>
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
