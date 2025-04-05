use leptos::prelude::*;

#[component]
pub fn GoalCard(title: String, description: String, progress: i32) -> impl IntoView {
    view! {
        <article class="rounded-xl border-2 border-gray-100 bg-white">
            <div class="flex items-start gap-4 p-4 sm:p-6 lg:p-8">

                <div>
                    <h3 class="font-medium sm:text-lg">
                        <a href="#" class="hover:underline">
                            Question about Livewire Rendering-3 and Alpine JS
                        </a>
                    </h3>

                    <p class="line-clamp-2 text-sm text-gray-700">
                        Lorem ipsum dolor, sit amet consectetur adipisicing elit. Accusamus, accusantium temporibus
                        iure delectus ut totam natus nesciunt ex? Ducimus, enim.
                    </p>

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

                            <p class="text-xs">Dec 31, 2024</p>
                        </div>

                        <span class="hidden sm:block" aria-hidden="true">
                            "·"
                        </span>

                        <p class="hidden sm:block sm:text-xs sm:text-gray-500">
                            Started 2 days ago
                        </p>
                    </div>
                </div>
            </div>

            <div class="flex justify-end">
                <strong class="-me-[2px] -mb-[2px] inline-flex items-center gap-1 rounded-ss-xl rounded-ee-xl bg-blue-600 px-3 py-1.5 text-white">
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
                            d="M13 10V3L4 14h7v7l9-11h-7z"
                        />
                    </svg>

                    <span class="text-[10px] font-medium sm:text-xs">In Progress</span>
                </strong>
            </div>
        </article>
    }
}
