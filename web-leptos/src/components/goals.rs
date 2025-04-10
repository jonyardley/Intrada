use leptos::prelude::*;

use shared::{PracticeGoal, Status};

#[component]
pub fn GoalCard(#[prop(into)] goal: PracticeGoal) -> impl IntoView {
    let PracticeGoal {
        id,
        name,
        description,
        status,
        start_date,
        target_date,
        exercise_ids: _,
        tempo_target: _,
    } = goal;
    view! {
        <article class="rounded-xl border-2 border-gray-100 bg-white">
            <div class="flex items-start gap-4 p-4 sm:p-6 lg:p-8">
                <div>
                    <h3 class="font-medium sm:text-lg">
                        <a href="#" class="hover:underline">
                            {name}
                        </a>
                    </h3>

                    <p class="line-clamp-2 text-sm text-gray-700">{description}</p>

                    <div class="mt-2 sm:flex sm:items-center sm:gap-2">
                        <div class="flex items-center gap-1 text-gray-500">
                            <svg
                                xmlns="http://www.w3.org/2000/svg"
                                class="size-4"
                                fill="none"
                                viewBox="0 0 24 24"
                                stroke="currentColor"
                                stroke-width="2"
                            >
                                <path
                                    stroke-linecap="round"
                                    stroke-linejoin="round"
                                    d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z"
                                />
                            </svg>

                            <p class="text-xs">{start_date.map(|date| date.to_string()).unwrap_or("Not set".to_string())}</p>
                            <p class="text-xs">{target_date.map(|date| date.to_string()).unwrap_or("Not set".to_string())}</p>

                        </div>
                    </div>
                    <p class="text-xs text-gray-500 mt-2">ID: {id}</p>
                </div>
            </div>

            <div class="flex justify-end">
                <StatusBadge status=status />
            </div>
        </article>
    }
}

#[component]
fn StatusBadge(#[prop(into)] status: Status) -> impl IntoView {
    let (bg_color, icon_path) = match status {
        Status::NotStarted => (
            "bg-gray-600",
            "M12 6v6h4.5m4.5 0a9 9 0 11-18 0 9 9 0 0118 0z",
        ),
        Status::InProgress => ("bg-blue-600", "M13 10V3L4 14h7v7l9-11h-7z"),
        Status::Completed => ("bg-green-600", "M5 13l4 4L19 7"),
    };

    let status_text = move || format!("{:?}", status);

    view! {
        <strong class=format!(
            "-me-[2px] -mb-[2px] inline-flex items-center gap-1 rounded-ss-xl rounded-ee-xl px-3 py-1.5 text-white {}",
            bg_color,
        )>
            <svg
                xmlns="http://www.w3.org/2000/svg"
                class="size-4"
                fill="none"
                viewBox="0 0 24 24"
                stroke="currentColor"
                stroke-width="2"
            >
                <path stroke-linecap="round" stroke-linejoin="round" d=icon_path />
            </svg>

            <span class="text-[10px] font-medium sm:text-xs">{status_text}</span>
        </strong>
    }
}

#[component]
pub fn GoalList(goals: impl Fn() -> Vec<PracticeGoal> + Send + Sync + 'static) -> impl IntoView {
    view! {
        <div class="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3">
            {move || {
                goals()
                    .iter()
                    .map(|goal| {
                        view! { <GoalCard goal=goal.clone() /> }
                    })
                    .collect_view()
            }}
        </div>
    }
}
