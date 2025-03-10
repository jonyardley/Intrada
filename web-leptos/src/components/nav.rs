use leptos::prelude::*;
use leptos_router::components::A;

#[component]
pub fn Nav() -> impl IntoView {

    view! {
        <div class="navbar bg-base-100">
            <div class="navbar-start">
                <div class="dropdown">
                    <div tabindex="0" role="button" class="btn btn-ghost lg:hidden">
                        <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor"> <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 6h16M4 12h8m-8 6h16" /> </svg>
                    </div>
                    <ul tabindex="0" class="menu menu-sm dropdown-content bg-base-100 rounded-box z-1 mt-3 w-52 p-2 shadow">
                    <li><A href="/routines">"Routines"</A></li>
                    <li><A href="/sessions">"Sessions"</A></li>
                    <li><A href="/exercises">"Exercises"</A></li>
                    <li><A href="/settings">"Settings"</A></li>
                    </ul>
                </div>
                <div class="btn btn-ghost text-xl"><A href="/">"Practice App"</A></div>
            </div>
            <div class="navbar-center hidden lg:flex">
                <ul class="menu menu-horizontal px-1">
                    <li><A href="/routines">"Routines"</A></li>
                    <li><A href="/sessions">"Sessions"</A></li>
                    <li><A href="/exercises">"Exercises"</A></li>
                    <li><A href="/settings">"Settings"</A></li>
                </ul>
            </div>
            <div class="navbar-end"></div>
        </div>
    }
}
