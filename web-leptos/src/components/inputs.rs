use leptos::prelude::*;

#[component]
pub fn TextInput(
    label: String,
    id: String,
    value: ReadSignal<String>,
    set_value: WriteSignal<String>,
) -> impl IntoView {
    view! {
        <label for=id.clone()>
            <span class="text-sm font-medium text-gray-700">{label}</span>

            <input
                type="text"
                id=id.clone()
                class="mt-0.5 w-full rounded border-gray-300 shadow-sm sm:text-sm"
                bind:value=(value, set_value)
            />
        </label>
    }
}

#[component]
pub fn DatePicker(
    label: String,
    value: ReadSignal<String>,
    id: String,
    set_value: WriteSignal<String>,
) -> impl IntoView {
    view! {
        <label for=id.clone()>
            <span class="text-sm font-medium text-gray-700">{label}</span>
            <div class="relative mt-0.5">
                <input
                    type="date"
                    id=id.clone()
                    class="w-full rounded border-gray-300 shadow-sm sm:text-sm focus:border-blue-500 focus:ring-blue-500"
                    prop:value=value
                    bind:value=(value, set_value)
                />
                <div class="absolute inset-y-0 right-0 flex items-center pr-3 pointer-events-none">
                    <svg
                        class="w-5 h-5 text-gray-400"
                        fill="none"
                        stroke="currentColor"
                        viewBox="0 0 24 24"
                    >
                        <path
                            stroke-linecap="round"
                            stroke-linejoin="round"
                            stroke-width="2"
                            d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z"
                        />
                    </svg>
                </div>
            </div>
        </label>
    }
}

#[component]
pub fn TempoInput(
    label: String,
    value: ReadSignal<String>,
    id: String,
    set_value: WriteSignal<String>,
) -> impl IntoView {
    view! {
        <label for=id.clone()>
            <span class="text-sm font-medium text-gray-700">{label}</span>
            <div class="relative mt-0.5">
                <input
                    type="number"
                    id=id.clone()
                    class="w-full rounded border-gray-300 shadow-sm sm:text-sm focus:border-blue-500 focus:ring-blue-500"
                    bind:value=(value, set_value)
                    min="20"
                    max="300"
                    step="1"
                />
                <div class="absolute inset-y-0 right-0 flex items-center pr-3 pointer-events-none">
                    <span class="text-gray-500 sm:text-sm">BPM</span>
                </div>
            </div>
        </label>
    }
}
