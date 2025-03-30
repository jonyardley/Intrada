use leptos::prelude::*;
use thaw::*;

#[component]
pub fn Goals() -> impl IntoView {
    let selected_value = RwSignal::new("active".to_string());

    view! {
        <section>
            <h2>"Goals"</h2>
            <p>"What do you want to achieve?"</p>
            <TabList selected_value>
                <Tab value="active">"Active"</Tab>
                <Tab value="paused">"Paused"</Tab>
                <Tab value="completed">"Completed"</Tab>
            </TabList>
            <Flex attr:style="padding: 20px;">
                <Grid cols=3 x_gap=20 y_gap=20>
                    <GoalCard />
                    <GoalCard />
                    <GoalCard />
                    <GoalCard />
                    <GoalCard />
                    <GoalCard />
                    <GoalCard />
                </Grid>
            </Flex>
        </section>
    }
}

#[component]
pub fn GoalCard() -> impl IntoView {
    let value = RwSignal::new(0.5);
    view! {
        <GridItem>
            <Card>
                <CardHeader>
                    <Body1>
                        <b>"Get good at scales"</b>
                    </Body1>
                    <CardHeaderDescription slot>
                        <Caption1>"Play all scales across two octaves"</Caption1>
                    </CardHeaderDescription>
                </CardHeader>
                <CardPreview>
                    <Flex gap=FlexGap::Medium vertical=true style="padding: 10px;">
                        <TagGroup size=TagSize::ExtraSmall>
                            <Tag>"Active"</Tag>
                            <Tag>"Technique"</Tag>
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
