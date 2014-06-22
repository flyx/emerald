
proc tags*(): TTagList {.compileTime.} =
    result = initTable[string, TTagHandling]()
    result["body"] = (requiredAttrs  : initSet[string](),
                    optionalAttrs  : initSet[string](),
                    requiredChilds : initSet[string](),
                    optionalChilds : initSet[string](),
                    instaClosable  : false)
    result["br"]  = (requiredAttrs  : initSet[string](),
                   optionalAttrs  : initSet[string](),
                   requiredChilds : initSet[string](),
                   optionalChilds : initSet[string](),
                   instaClosable  : true)
    result["div"] = (requiredAttrs  : initSet[string](),
                   optionalAttrs  : initSet[string](),
                   requiredChilds : initSet[string](),
                   optionalChilds : initSet[string](),
                   instaClosable  : false)
    result["h1"] = (requiredAttrs  : initSet[string](),
                  optionalAttrs  : initSet[string](),
                  requiredChilds : initSet[string](),
                  optionalChilds : initSet[string](),
                  instaClosable  : false)
    result["h2"] = (requiredAttrs  : initSet[string](),
                  optionalAttrs  : initSet[string](),
                  requiredChilds : initSet[string](),
                  optionalChilds : initSet[string](),
                  instaClosable  : false)
    result["h3"] = (requiredAttrs  : initSet[string](),
                  optionalAttrs  : initSet[string](),
                  requiredChilds : initSet[string](),
                  optionalChilds : initSet[string](),
                  instaClosable  : false)
    result["h4"] = (requiredAttrs  : initSet[string](),
                  optionalAttrs  : initSet[string](),
                  requiredChilds : initSet[string](),
                  optionalChilds : initSet[string](),
                  instaClosable  : false)
    result["h5"] = (requiredAttrs  : initSet[string](),
                  optionalAttrs  : initSet[string](),
                  requiredChilds : initSet[string](),
                  optionalChilds : initSet[string](),
                  instaClosable  : false)
    result["h6"] = (requiredAttrs  : initSet[string](),
                  optionalAttrs  : initSet[string](),
                  requiredChilds : initSet[string](),
                  optionalChilds : initSet[string](),
                  instaClosable  : false)
    result["head"] = (requiredAttrs  : initSet[string](),
                    optionalAttrs  : initSet[string](),
                    requiredChilds : toSet[string](["title"]),
                    optionalChilds : initSet[string](),
                    instaClosable  : false)
    result["html"] = (requiredAttrs  : initSet[string](),
                    optionalAttrs  : initSet[string](),
                    requiredChilds : toSet[string](["head", "body"]),
                    optionalChilds : initSet[string](),
                    instaClosable  : false)
    result["p"] = (requiredAttrs  : initSet[string](),
                 optionalAttrs  : initSet[string](),
                 requiredChilds : initSet[string](),
                 optionalChilds : initSet[string](),
                 instaClosable  : false)
    result["script"] = (requiredAttrs : initSet[string](),
                      optionalAttrs : toSet(["type"]),
                      requiredChilds: initSet[string](),
                      optionalChilds: initSet[string](),
                      instaClosable : false)
    result["span"] = (requiredAttrs  : initSet[string](),
                    optionalAttrs  : initSet[string](),
                    requiredChilds : initSet[string](),
                    optionalChilds : initSet[string](),
                    instaClosable  : false)
    result["table" ] = (requiredAttrs  : initSet[string](),
                      optionalAttrs  : initSet[string](),
                      requiredChilds : initSet[string](),
                      optionalChilds : toSet[string](["thead", "tbody", "tr"]),
                      instaClosable  : false)
    result["th" ] = (requiredAttrs  : initSet[string](),
                      optionalAttrs  : initSet[string](),
                      requiredChilds : initSet[string](),
                      optionalChilds : initSet[string](),
                      instaClosable  : false)
    result["thead" ] = (requiredAttrs  : initSet[string](),
                      optionalAttrs  : initSet[string](),
                      requiredChilds : initSet[string](),
                      optionalChilds : toSet[string](["tr"]),
                      instaClosable  : false)
    result["tr" ] = (requiredAttrs  : initSet[string](),
                      optionalAttrs  : initSet[string](),
                      requiredChilds : initSet[string](),
                      optionalChilds : toSet[string](["th", "td"]),
                      instaClosable  : false)
    result["title" ] = (requiredAttrs  : initSet[string](),
                      optionalAttrs  : initSet[string](),
                      requiredChilds : initSet[string](),
                      optionalChilds : initSet[string](),
                      instaClosable  : false)