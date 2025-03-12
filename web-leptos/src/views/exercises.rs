use crate::components::typography::Header1;
use leptos::prelude::*;

#[component]
pub fn Exercises() -> impl IntoView {
    let (exercise_name, set_exercise_name) = signal("".to_string());

    view! {
        <Header1 text="Exercises" />
        <section class="mb-5">
            <input
                type="text"
                class="input"
                placeholder="Exercise Name"
                on:input:target=move |ev| {
                    set_exercise_name.set(ev.target().value());
                }
            />
            <button class="btn">Add Exercise</button>
        </section>
        <p>{exercise_name}</p>
        <section>
            <ul>
                <li>Exercise 1</li>
                <li>Exercise 2</li>
                <li>Exercise 3</li>
            </ul>
        </section>
    }
}
