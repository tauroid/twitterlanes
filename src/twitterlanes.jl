module twitterlanes

using HTTP
using JSON
using Dates
using Random
using Base64
using SHA

oauth_consumer_key = ""
oauth_token = ""

consumer_secret = ""
token_secret = ""

uid = ""
bearer_token = ""

function oauth_request(method, url, headers=[], body="")
    oauth_nonce = randstring(32)
    oauth_signature_method = "HMAC-SHA1"
    oauth_timestamp = string(floor(Int, datetime2unix(now())))
    oauth_version = "1.0"

    urlsplit = split(url,'?')
    if length(urlsplit) == 1
        query = ""
    elseif length(urlsplit) == 2
        query = urlsplit[2]
    else
        error("Url should only have maximum one '?'")
    end

    params = Dict()
    for s in split(query,'&')
        (k,v) = split(s,'=')
        params[HTTP.escapeuri(HTTP.unescapeuri(k))] =
            HTTP.escapeuri(HTTP.unescapeuri(v))
    end
    if !isempty(body)
        for s in split(body,'&')
            (k,v) = split(s,'=')
            params[HTTP.escapeuri(HTTP.unescapeuri(k))] =
                HTTP.escapeuri(HTTP.unescapeuri(v))
        end
    end

    oauth_params = Dict()
    oauth_params["oauth_consumer_key"] = oauth_consumer_key
    oauth_params["oauth_nonce"] = oauth_nonce
    oauth_params["oauth_signature_method"] = oauth_signature_method
    oauth_params["oauth_timestamp"] = oauth_timestamp
    oauth_params["oauth_token"] = oauth_token
    oauth_params["oauth_version"] = oauth_version

    oauth_params = map((p)->map(HTTP.escapeuri,p), collect(oauth_params))

    params = [collect(params); oauth_params]
    params = sort(params; by=first)
    params_str = join(map(((k,v),)->"$k=$v", params), '&')

    base_string = "$method&$(HTTP.escapeuri(urlsplit[1]))&$(HTTP.escapeuri(params_str))"
    signing_key = Vector{UInt8}("$(HTTP.escapeuri(consumer_secret))&$(HTTP.escapeuri(token_secret))")

    oauth_signature = base64encode(SHA.hmac_sha1(signing_key,base_string))

    oauth_params = [oauth_params;
                    "oauth_signature" => HTTP.escapeuri(oauth_signature)]
    oauth_params_str = join(map(((k,v),)->"$k=\"$v\"", oauth_params),", ")
    auth = "OAuth $oauth_params_str"

    HTTP.request(method, url, [headers; "Authorization" => auth], body)
end

function go()
    bh = "Authorization" => "Bearer $bearer_token"

    follows = []

    # get user follows
    next_token = ""
    while !isnothing(next_token)
        b = JSON.parse(String(HTTP.get("https://api.twitter.com/2/users/$uid/following?max_results=1000$next_token", [bh]).body))
        next_token =
            try string("&pagination_token=", b["meta"]["next_token"])
            catch e
                if e isa KeyError nothing else throw(e) end
            end
        follows = vcat(follows, b["data"])
    end

    finfo = Dict()

    i = 1
    while i <= length(follows)
        ids = map((f)->f["id"], follows[i:(i+99 <= length(follows) ? i+99 : length(follows))])
        b = JSON.parse(String(HTTP.get("https://api.twitter.com/2/users?user.fields=created_at,public_metrics&ids=$(join(ids, ","))", [bh]).body))
        for u in b["data"]
            finfo[u["id"]] = u
        end
        i += 100
    end

    rates = Dict()

    for (k,v) in finfo
        rates[k] = v["public_metrics"]["tweet_count"]/(now()-DateTime(v["created_at"][1:end-1])).value
    end

    rates = sort(collect(rates); by=last, rev=true)

    totalrate = sum(map(last,rates))

    nlists = 3
    lists = repeat([[]], nlists)
    listrates = map((i)->exp(-i/2),1:nlists)
    listrates /= sum(listrates)
    listrates *= totalrate

    rate = 0
    l = 1
    for (k,v) in rates
        lists[l] = [lists[l]; k]
        rate += v
        if l < nlists && rate >= listrates[l]
            rate = 0
            l += 1
        end
    end

    println(lists)

    for i in 1:nlists
        name = "Speed%20lane%20$i"

        l = lists[i]

        r = oauth_request("POST", "https://api.twitter.com/1.1/lists/create.json?name=$name&mode=private")
        println(r)
        b = JSON.parse(String(r.body))
        lid = b["id"]

        j = 1
        while j < length(l)
            id_str = join(j+99 <= length(l) ? l[j:(j+99)] : l[j:end], ",")
            println(id_str)
            r = oauth_request(
                "POST",
                "https://api.twitter.com/1.1/lists/members/create_all.json?list_id=$lid",
                ["Content-Type" => "application/x-www-form-urlencoded"],
                "user_id=$id_str")
            j += 100
        end
    end
end

end # module
