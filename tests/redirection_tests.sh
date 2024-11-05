echo "Hello, minishell!" > output.txt
cat output.txt

echo "This should overwrite the previous content" > output.txt
cat output.txt


echo "First line" > append_test.txt
echo "Second line" >> append_test.txt
cat append_test.txt

echo "Third line" >> append_test.txt
echo "Fourth line" >> append_test.txt
cat append_test.txt 

echo "Reading this line from a file" > input_test.txt
cat < input_test.txt

wc -w < input_test.txt 

ls valid_file.txt non_existent_file.txt > output_log.txt 2> error_log.txt
cat output_log.txt  
cat error_log.txt

ls valid_file.txt non_existent_file.txt > combined_log.txt 2>&1
cat combined_log.txt

echo "This will not be seen" > /dev/null
ls > /dev/null

echo "Testing write error" > /root/forbidden.txt

cat < non_existent_file.txt

mkdir directory_test
echo "Trying to write to a directory" > directory_test

rm -r directory_test

echo "Line 1" | grep "Line" > pipe_output.txt
cat pipe_output.txt

echo "Word count test" > pipe_input.txt
cat < pipe_input.txt | wc -w > pipe_wc_output.txt
cat pipe_wc_output.txt

echo "Redirection test line" > multi_redir_input.txt
cat < multi_redir_input.txt > multi_redir_output.txt
cat multi_redir_output.txt

rm -f output.txt append_test.txt input_test.txt output_log.txt error_log.txt combined_log.txt pipe_output.txt pipe_input.txt pipe_wc_output.txt multi_redir_input.txt multi_redir_output.txt


