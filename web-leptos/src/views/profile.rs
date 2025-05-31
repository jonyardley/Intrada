use leptos::*;
use leptos_meta::*;

#[component]
pub fn Profile() -> impl IntoView {
    view! {
        <div class="min-h-screen bg-gray-50">
            <div class="max-w-2xl mx-auto py-8 px-4">
                // Profile header
                <div class="text-center mb-8">
                    <div class="w-24 h-24 mx-auto bg-gray-200 rounded-full flex items-center justify-center mb-4">
                        <svg
                            class="w-12 h-12 text-gray-500"
                            fill="currentColor"
                            viewBox="0 0 20 20"
                        >
                            <path
                                fill-rule="evenodd"
                                d="M10 9a3 3 0 100-6 3 3 0 000 6zm-7 9a7 7 0 1114 0H3z"
                                clip-rule="evenodd"
                            />
                        </svg>
                    </div>
                    <h2 class="text-xl font-semibold text-gray-900">"User Name"</h2>
                    <p class="text-gray-500">"user@example.com"</p>
                </div>

                // Settings sections
                <div class="bg-white rounded-lg shadow-sm overflow-hidden mb-6">
                    <SettingsRow icon="person" title="Edit Profile" />
                    <SettingsRow icon="bell" title="Notifications" />
                    <SettingsRow icon="lock" title="Privacy" />
                    <SettingsRow icon="question-mark-circle" title="Help & Support" />
                    <SettingsRow icon="cog" title="Settings" />
                </div>

                // Sign out button
                <button class="w-full py-3 px-4 text-red-600 bg-white rounded-lg shadow-sm hover:bg-gray-50 transition-colors">
                    "Sign Out"
                </button>
            </div>
        </div>
    }
}

#[component]
fn SettingsRow(icon: &'static str, title: &'static str) -> impl IntoView {
    view! {
        <div class="flex items-center px-4 py-3 border-b border-gray-100 last:border-b-0 hover:bg-gray-50 transition-colors">
            <div class="w-8 h-8 flex items-center justify-center text-gray-500">
                <svg class="w-5 h-5" fill="currentColor" viewBox="0 0 20 20">
                    {match icon {
                        "person" => {
                            view! {
                                <path
                                    fill-rule="evenodd"
                                    d="M10 9a3 3 0 100-6 3 3 0 000 6zm-7 9a7 7 0 1114 0H3z"
                                    clip-rule="evenodd"
                                />
                            }
                        }
                        "bell" => {
                            view! {
                                <path d="M10 2a6 6 0 00-6 6v3.586l-.707.707A1 1 0 004 14h12a1 1 0 00.707-1.707L16 11.586V8a6 6 0 00-6-6zM10 18a3 3 0 01-3-3h6a3 3 0 01-3 3z" />
                            }
                        }
                        "lock" => {
                            view! {
                                <path
                                    fill-rule="evenodd"
                                    d="M5 9V7a5 5 0 0110 0v2a2 2 0 012 2v5a2 2 0 01-2 2H5a2 2 0 01-2-2v-5a2 2 0 012-2zm8-2v2H7V7a3 3 0 016 0z"
                                    clip-rule="evenodd"
                                />
                            }
                        }
                        "question-mark-circle" => {
                            view! {
                                <path
                                    fill-rule="evenodd"
                                    d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-8-3a1 1 0 00-.867.5 1 1 0 11-1.731-1A3 3 0 0113 8a3.001 3.001 0 01-2 2.83V11a1 1 0 11-2 0v-1a1 1 0 011-1 1 1 0 100-2zm0 8a1 1 0 100-2 1 1 0 000 2z"
                                    clip-rule="evenodd"
                                />
                            }
                        }
                        "cog" => {
                            view! {
                                <path
                                    fill-rule="evenodd"
                                    d="M11.49 3.17c-.38-1.56-2.6-1.56-2.98 0a1.532 1.532 0 01-2.286.948c-1.372-.836-2.942.734-2.106 2.106.54.886.061 2.042-.947 2.287-1.561.379-1.561 2.6 0 2.978a1.532 1.532 0 01.947 2.287c-.836 1.372.734 2.942 2.106 2.106a1.532 1.532 0 012.287.947c.379 1.561 2.6 1.561 2.978 0a1.533 1.533 0 012.287-.947c1.372.836 2.942-.734 2.106-2.106a1.533 1.533 0 01.947-2.287c1.561-.379 1.561-2.6 0-2.978a1.532 1.532 0 01-.947-2.287c.836-1.372-.734-2.942-2.106-2.106a1.532 1.532 0 01-2.287-.947zM10 13a3 3 0 100-6 3 3 0 000 6z"
                                    clip-rule="evenodd"
                                />
                            }
                        }
                        _ => {
                            view! {
                                <path
                                    fill-rule="evenodd"
                                    d="M10 9a3 3 0 100-6 3 3 0 000 6zm-7 9a7 7 0 1114 0H3z"
                                    clip-rule="evenodd"
                                />
                            }
                        }
                    }}
                </svg>
            </div>
            <span class="ml-3 text-gray-900">{title}</span>
            <div class="ml-auto">
                <svg class="w-5 h-5 text-gray-400" fill="currentColor" viewBox="0 0 20 20">
                    <path
                        fill-rule="evenodd"
                        d="M7.293 14.707a1 1 0 010-1.414L10.586 10 7.293 6.707a1 1 0 011.414-1.414l4 4a1 1 0 010 1.414l-4 4a1 1 0 01-1.414 0z"
                        clip-rule="evenodd"
                    />
                </svg>
            </div>
        </div>
    }
}
