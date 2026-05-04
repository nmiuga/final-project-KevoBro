# reflection.md

Replace this file's contents with a short (150-300 word) reflection on your final project. Must be human-generated text. Headings encouraged, bullet points okay.

## Overall Learnings
After completing this project, I better understand the capabilities of SwiftUI regarding its animation features. Overall, it supports simple shape/motion animations and color changing, but none of the advanced features that come with dedicated game engines like Unity, which is to be expected. I also tried image generation for the first time via ChatGPT and had some generally good results. I found that the AI is limited in trying to recreate or cut out certain sections of an image it generated previously. 

For example, I asked it to create a forest landscape with a large open sky as a background. Then, I requested it to provide two images, one with only the open sky, and the other image with only the landscape, as well as having the section where the sky would be, be transparent. The AI ended up generating an entirely new landscape, which led me to manually edit the initial photo and cut out the sky. 


## Challenges

During the course of this project, I was able to recognize the limits of the chat agent regarding the memory load or maximum length of the prompt that it could take in. Since building a good app with AI depends on a great baseline structure, I was meticulous and detailed in describing the type of game that I wanted the AI to make. This included describing the game mechanics to the best of my ability and providing a step-by-step example of how that game mechanic would function in-game. 

This ended up with me having an extremely large prompt that could not be loaded in all at once. As a result, I had to broke it up into multiple segments and prompt the AI to take in each chunk of the prompt without making changes, and then creating once everything had been submitted. I was worried that submitting so many prompts without generating would ruin the AI's memory of the earlier details, but the initial generation turned out very good. 

## Next Steps

If I were to continue working on this app, I would want to improve further on the visuals/animations that occur when the player accomplishes certain actions. For example, I would like to add some pop-up texts and narration similar to Candy Crush, where the announcer comments "tasty" or "sweet!" Another one would be the background becoming an animated rainbow gradient once the player reaches a combo chain of 10+, adding onto that dopamine rush that I want to recreate based on games similar to this. 

Another improvement I would make is custom sound effects, such as the orbs moving and when orbs are matched. As of right now, the sound effects are just native IOS sound effects like the IOS keyboard tap for when orbs are being shuffled. I believe that the sound could become repetitive, so I would like to add some variety and give the game more of a unique identity. 

Lastly, my biggest desire would be to have the app be supported by GameCenter, which would allow me to have a friend scoreboard that the user could reference based on their contacts/friend invites. 
 
