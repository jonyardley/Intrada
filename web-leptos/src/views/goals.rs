use leptos::prelude::*;
use thaw::*;

use crate::core;
use crate::GlobalState;
use reactive_stores::Store;
use shared::PracticeGoal;

#[component]
pub fn Goals() -> impl IntoView {
    let state = expect_context::<Store<GlobalState>>().get_untracked();
    let core = state.core;
    let (view, render) = signal(core.view());
    let (event, _) = signal(shared::Event::GetGoals);

    Effect::new(move |_| {
        core::update(&core, event.get(), render);
    });

    let selected_value = RwSignal::new("all".to_string());

    view! {
        <div>
            <h2>"Goals"</h2>
            <p>"What do you want to achieve?"</p>

            <TabList selected_value>
                <Tab value="all">"All"</Tab>
                <Tab value="active">"Active"</Tab>
                <Tab value="paused">"Paused"</Tab>
                <Tab value="completed">"Completed"</Tab>
            </TabList>

            <div>

                <Grid cols=3 x_gap=8 y_gap=8>
                    {move || {
                        view.get()
                            .goals
                            .iter()
                            .map(|goal| {
                                view! { <GoalCard goal=goal.clone() /> }
                            })
                            .collect_view()
                            .into_any()
                    }}
                </Grid>
            </div>

        </div>
    }
}

#[component]
pub fn GoalCard(goal: PracticeGoal) -> impl IntoView {
    let value = RwSignal::new(goal.progress);

    view! {
        <GridItem>
            <Card>
                <CardHeader>
                    <Body1>
                        <b>{goal.name}</b>
                    </Body1>
                    <CardHeaderDescription slot>
                        <Caption1>{goal.description}</Caption1>
                    </CardHeaderDescription>
                </CardHeader>
                <CardPreview>
                    <Flex gap=FlexGap::Medium vertical=true>
                        <TagGroup size=TagSize::ExtraSmall>
                            {goal
                                .tags
                                .clone()
                                .into_iter()
                                .map(|tag| view! { <Tag>{tag}</Tag> })
                                .collect_view()
                                .into_any()}
                        </TagGroup>
                        <ProgressBar value=value />
                    </Flex>
                </CardPreview>
                <CardFooter>
                    <Button>"Details"</Button>
                </CardFooter>
            </Card>
        </GridItem>
    }
}
