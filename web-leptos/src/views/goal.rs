use leptos::prelude::*;
use leptos_router::{hooks::use_params, params::Params};
use shared::GoalStatus;

use crate::components::{Header, Main, H2};
use crate::hooks::{nothing_event, use_core};

#[component]
pub fn Goal() -> impl IntoView {
    let params = use_params::<GoalParams>();
    let (view, _) = use_core(nothing_event());

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
                                        <p class="text-sm font-medium text-gray-500">"Start Date"</p>
                                        <p class="text-gray-700">
                                            {goal.start_date.unwrap_or_else(|| "Not set".to_string())}
                                        </p>
                                    </div>
                                    <div>
                                        <p class="text-sm font-medium text-gray-500">"Target Date"</p>
                                        <p class="text-gray-700">
                                            {goal.target_date.unwrap_or_else(|| "Not set".to_string())}
                                        </p>
                                    </div>
                                </div>
                            </div>

                            <div>
                                <H2 text="Studies".to_string() />
                                <p class="text-gray-700">
                                    {format!("{} studies linked", goal.study_ids.len())}
                                </p>
                            </div>
                        </div>
                    </Main>
                }
                    .into_any()
            } else {
                view! {
                    <Header title="Goal Not Found".to_string() />
                    <Main>
                        <p>"Goal not found"</p>
                    </Main>
                }
                    .into_any()
            }
        }}
    }
}

#[derive(Params, PartialEq, Clone)]
struct GoalParams {
    id: Option<String>,
}
