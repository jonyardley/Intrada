use leptos::prelude::*;

use crate::components::GoalCard;
use crate::components::Header;

#[component]
pub fn Home() -> impl IntoView {
    view! {
        <Header />
        <main class="mx-auto max-w-7xl px-4 py-6 sm:px-6 lg:px-8">
            <h2 class="text-2xl font-bold">"Here are your active goals"</h2>
            <div class="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3">
                <GoalCard
                    title="Goal 1".to_string()
                    description="Description 1".to_string()
                    progress=50
                />
                <GoalCard
                    title="Goal 2".to_string()
                    description="Description 2".to_string()
                    progress=75
                />
                <GoalCard
                    title="Goal 3".to_string()
                    description="Description 3".to_string()
                    progress=100
                />
            </div>
        </main>
    }
}
