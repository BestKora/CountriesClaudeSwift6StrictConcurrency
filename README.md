## iOS apps Countries using Claude 3.5 Sonnet, ChatGPT 4.o1, ChatGPT 4.o1-preview and Gemini 2.0 Flash

 A simple iOS application Countries, which shows all the countries of the World by region (Europe, Asia, Latin America, etc.) 
 and for each country its name and flag. 
 
 If you select a country, then additional information about the population 
 and the size of GDP (gross domestic product) gdp is reported:

 ![til](https://github.com/BestKora/CountriesClaudeAsync/blob/0256985111f33836927cfed3d23ecb671255e254/CountriesA.png)

 With Claude 3.5 Sonnet, we get a great iOS app on with a Data Model to decode JSON data, with a CountriesViewModel that fetches all the necessary information from the World Bank server, converts the JSON data into Model data, and provides Views to display on the user's screen. 
 
 ![til](https://github.com/BestKora/CountriesClaudeAsync/blob/9163c15898e4e52e014ae8b9fe2ed8fcaaa61582/CreateCountriesApp.png)
 ![til](https://github.com/BestKora/CountriesClaudeAsync/blob/0f795d634634fa98c32e77456ebf28208bd4ffe5/CreateCountriesAppWorldBank.png)
 We don't specify a single link to the World Bank sites, or a single hint about the data structure, and yet we get a fully functional iOS app. 
 
 We also used ChatGPT 4.o1-mini , ChatGPT 4.o1-preview , and Gemini 2.0 Flash

## Technologies

* MVVM design pattern 
* SwiftUI
* GCD
* async / await
* Swift 6 strict concurrency

  ## This is Swift 6 strict concurrency version

[But there is GCD version](https://github.com/BestKora/CountriesClaude)

[And async / await version](https://github.com/BestKora/CountriesClaudeAsync)

