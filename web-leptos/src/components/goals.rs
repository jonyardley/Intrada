use leptos::prelude::*;

use leptos_router::components::A;
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
        exercise_ids,
        tempo_target: _,
    } = goal;
    view! {
        <article class="rounded-xl border-2 border-gray-100 bg-white">
            <div class="flex items-start gap-4 p-4 sm:p-6 lg:p-8">
                <div>
                    <h3 class="font-medium sm:text-lg">
                        <A href=format!("/goals/{}", id) attr:class="hover:underline">
                            {name}
                        </A>
                    </h3>

                    <p class="line-clamp-2 text-sm text-gray-700">{description}</p>

                    <div class="mt-2 flex items-center gap-1 text-gray-500">
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
                                d="M4.26 10.147a60.436 60.436 0 00-.491 6.347A48.627 48.627 0 0112 20.904a48.627 48.627 0 018.232-4.41 60.46 60.46 0 00-.491-6.347m-15.482 0a50.57 50.57 0 00-2.658-.813A59.905 59.905 0 0112 3.493a59.902 59.902 0 0110.399 5.84c-.896.248-1.783.52-2.658.814m-15.482 0A50.697 50.697 0 0112 13.489a50.702 50.702 0 017.74-3.342M6.75 15a.75.75 0 100-1.5.75.75 0 000 1.5zm0 0v-3.675A55.378 55.378 0 0112 8.443m-7.007 11.55A5.981 5.981 0 006.75 15.75v-1.5"
                            />
                        </svg>
                        <p class="text-xs">{format!("{} exercises", exercise_ids.len())}</p>
                    </div>

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

                            <p class="text-xs">
                                {start_date
                                    .map(|date| date.to_string())
                                    .unwrap_or("Not set".to_string())}
                            </p>
                            <span class="text-xs text-gray-500">"·"</span>
                            <p class="text-xs">
                                {target_date
                                    .map(|date| date.to_string())
                                    .unwrap_or("Not set".to_string())}
                            </p>

                        </div>
                    </div>
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
