// MIT License
//
// Copyright 2018 Electric Imp
//
// SPDX-License-Identifier: MIT
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be
// included in all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
// EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
// MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO
// EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES
// OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
// ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
// OTHER DEALINGS IN THE SOFTWARE.

class CookiesTestCase extends ImpTestCase {
    _bayeuxClient = null;

    function testPositive1() {
        // In this test we expect the cookie to be added as "a" : "b"
        const COOKIE_STRING = "a=b";
        local expectedTable = {"a" : "b"};

        _bayeuxClient = Bayeux.Client({"url" : ""});

        local headers = [{"k" : "set-cookie", "v" : COOKIE_STRING}];
        _bayeuxClient._updateCookies(headers);

        this.assertTrue(_areEqualTables(_bayeuxClient._cookies, expectedTable));
    }

    function testPositive2() {
        // In this test we expect the cookie to be added as "a" : "b"
        const COOKIE_STRING = "a=b; Path=/; Domain=example.com";
        local expectedTable = {"a" : "b"};

        _bayeuxClient = Bayeux.Client({"url" : ""});

        local headers = [{"k" : "Set-cookie", "v" : COOKIE_STRING}];
        _bayeuxClient._updateCookies(headers);

        this.assertTrue(_areEqualTables(_bayeuxClient._cookies, expectedTable));
    }

    function testPositive3() {
        // In this test we expect the cookie to be added as "abababab" : "bcbcbcb"
        const COOKIE_STRING = "abababab=bcbcbcb; Path=/; Domain=example.com";
        local expectedTable = {"abababab" : "bcbcbcb"};

        _bayeuxClient = Bayeux.Client({"url" : ""});

        local headers = [{"k" : "Set-Cookie", "v" : COOKIE_STRING}];
        _bayeuxClient._updateCookies(headers);

        this.assertTrue(_areEqualTables(_bayeuxClient._cookies, expectedTable));
    }

    function testPositive4() {
        // In this test we expect the cookie to be added as "abababab" : "bcbcbcb"
        const COOKIE_STRING = "abababab = bcbcbcb; Path=/; Domain=example.com";
        local expectedTable = {"abababab" : "bcbcbcb"};

        _bayeuxClient = Bayeux.Client({"url" : ""});

        local headers = [{"k" : "Set-Cookie", "v" : COOKIE_STRING}];
        _bayeuxClient._updateCookies(headers);

        this.assertTrue(_areEqualTables(_bayeuxClient._cookies, expectedTable));
    }

    function testPositive5() {
        // In this test we expect the cookie to be added as "abababab" : "bcbcbcb"
        const COOKIE_STRING = "abababab=; Path=/; Domain=example.com";
        local expectedTable = {"abababab" : ""};

        _bayeuxClient = Bayeux.Client({"url" : ""});

        local headers = [{"k" : "Set-Cookie", "v" : COOKIE_STRING}];
        _bayeuxClient._updateCookies(headers);

        this.assertTrue(_areEqualTables(_bayeuxClient._cookies, expectedTable));
    }

    function testPositive6() {
        // In this test we expect the cookie to be added as "abababab" : "bcbcbcb"
        const COOKIE_STRING = "abababab=";
        local expectedTable = {"abababab" : ""};

        _bayeuxClient = Bayeux.Client({"url" : ""});

        local headers = [{"k" : "Set-Cookie", "v" : COOKIE_STRING}];
        _bayeuxClient._updateCookies(headers);

        this.assertTrue(_areEqualTables(_bayeuxClient._cookies, expectedTable));
    }

    function testNegative1() {
        // In this test we expect the cookie NOT to be added due to the header's wrong name
        const COOKIE_STRING = "a=b";

        _bayeuxClient = Bayeux.Client({"url" : ""});

        local headers = [{"k" : "Set-cookieS", "v" : COOKIE_STRING}];
        _bayeuxClient._updateCookies(headers);

        this.assertTrue(_bayeuxClient._cookies.len() == 0);
    }

    function testNegative2() {
        // In this test we expect the cookie NOT to be added due to empty name
        const COOKIE_STRING = "=bcbcb";

        _bayeuxClient = Bayeux.Client({"url" : ""});

        local headers = [{"k" : "set-cookie", "v" : COOKIE_STRING}];
        _bayeuxClient._updateCookies(headers);

        this.assertTrue(_bayeuxClient._cookies.len() == 0);
    }

    function testNegative3() {
        // In this test we expect the cookie NOT to be added due to empty name
        const COOKIE_STRING = "=";

        _bayeuxClient = Bayeux.Client({"url" : ""});

        local headers = [{"k" : "set-cookie", "v" : COOKIE_STRING}];
        _bayeuxClient._updateCookies(headers);

        this.assertTrue(_bayeuxClient._cookies.len() == 0);
    }

    function _areEqualTables(tbl1, tbl2) {
        if (tbl1.len() != tbl2.len()) {
            return false;
        }
        foreach (k, v in tbl1) {
            if (!(k in tbl2 && tbl2[k] == v)) {
                return false;
            }
        }
        return true;
    }
}