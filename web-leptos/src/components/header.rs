use leptos::prelude::*;
use thaw::*;

#[component]
pub fn header() -> impl IntoView {
    view! {
        <Flex justify=FlexJustify::End>
            <h1>"Practice App"</h1>
            <Flex align=FlexAlign::Center>
                <Icon icon=icondata::FiMusic attr:style="font-size: 2rem;" />
            </Flex>
        </Flex>
        <Divider />
    }
}
