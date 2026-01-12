const CodeTab = {
    init: function() {
        const container = document.getElementById('tab-content-2');
        container.innerHTML = `
            <div class="code-container">
                <!-- Сайдбар с задачей -->
                <div class="code-sidebar">
                    <div class="task-header">Merge Two Sorted Lists</div>
                    <div class="task-tag">Easy</div>
                    <div class="task-desc">
                        You are given the heads of two sorted linked lists list1 and list2.<br><br>
                        Merge the two lists in a one sorted list. The list should be made by splicing together the nodes of the first two lists.<br><br>
                        Return the head of the merged linked list.
                    </div>
                    <div class="task-example">
                        Input: list1 = [1,2,4], list2 = [1,3,4]<br>
                        Output: [1,1,2,3,4,4]
                    </div>
                </div>

                <!-- Редактор кода -->
                <div class="code-editor">
                    <div class="editor-tabs">
                        <div class="editor-tab">solution.js</div>
                    </div>
                    <div class="editor-content">
                        <div class="line-numbers">
                            1<br>2<br>3<br>4<br>5<br>6<br>7<br>8<br>9<br>10<br>11
                        </div>
                        <div class="code-area" contenteditable="true">
<span class="com">/**
 * Definition for singly-linked list.
 * function ListNode(val, next) {
 *     this.val = (val===undefined ? 0 : val)
 *     this.next = (next===undefined ? null : next)
 * }
 */</span>
<span class="kw">var</span> <span class="fn">mergeTwoLists</span> = <span class="kw">function</span>(list1, list2) {
    <span class="com">// Write your code here...</span>
    <span class="kw">if</span> (!list1) <span class="kw">return</span> list2;
    <span class="kw">if</span> (!list2) <span class="kw">return</span> list1;

    <span class="kw">let</span> head;

};
                        </div>
                    </div>
                </div>
            </div>
        `;
    }
};
