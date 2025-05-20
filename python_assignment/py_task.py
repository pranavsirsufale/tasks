import mysql.connector 
import csv


employee_array = []
with open('emp.csv',mode='r',newline='', encoding='utf-8') as csvfile:
    emp_records = csv.reader(csvfile)
    for emp in emp_records:
        employee_array.append(emp)
del employee_array[0]
employee_array.pop()


connection = mysql.connector.connect(
    host = 'localhost',
    user = 'root',
    password = 'Pranav@123',
    database='employee',
)
cursor = connection.cursor()



try:

    def get_records():
        cursor.execute("select * from employee_info;")
        myresult = cursor.fetchall()
        if len(myresult) == 0:
            raise Exception("No Record Found")
        print(cursor.rowcount,"Records fetched")
        for record in myresult:
            print(record)

        connection.commit()
    
    def add_records(recor):
        row_count = 0
        for record in recor:
            cursor.execute(f"insert into employee_info (`name`,`surname`,`employee_no`,`designation`,`joining_date`, `address`) values( '{record[0]}' , '{record[1]}' , '{record[2]}5' , '{record[3]}' , '{record[4]}' , '{','.join(record[5:])}');")  
            row_count += cursor.rowcount
        print(row_count,"records added")
        connection.commit()
    
    def remove_all_records():
        cursor.execute('delete from employee_info where id > 0;')
        print(cursor.rowcount(), "Record affected")
        connection.commit()

    def delete_record(id):
        cursor.execute(f"delete from employee_info where id=`{id}`;")
        print(cursor.rowcount(), "Record affected")
        connection.commit()
        
    def update_record(id, name,surname,designation,address ):
        cursor.execute(f"update employee_info set name='{name}',surname='{surname}',designation='{designation}',address='{address}' where id={id};")
        print(cursor.rowcount, "Record affected")
        connection.commit()

    def fetch_a_record(id):
        cursor.execute(f"select * from employee_info where id={id};")
        em_record = cursor.fetchone()
        if len(em_record) == 0:
            raise Exception("No record found")
        return em_record  

    def add_record(rec):
        pass    

except Exception as e:
    print(e)



print('''
1. Enter 1 for adding 10 records from the csv file
2. Enter 2 for Removing all the records 
3. Enter 3 for getting all records.
4. Enter 4 to delete a record
5. Enter 5 to fetch a record
6. Enter 6 to update a record
''')

operation = int(input('Select the below operations: '))

match operation:
    case 1:
        add_records(employee_array)
        
    case 2:
        remove_all_records()
        
    case 3:
        get_records()
        
    case 4:
        emp_id = int(input('Please enter Id of an employee: '))
        delete_record(emp_id)
    
    case 5:
        emp_id = int(input('Please enter Id of an employee: '))
        an_employee = fetch_a_record(emp_id)
        print(an_employee)

    case 6:
        emp_id = int(input('Please enter Id of an employee: '))
        emp_detail = fetch_a_record(emp_id)
        print(emp_detail)
        print('========================================')
        print("If you want to make changes then enter updated details otehrwise leave it blank ")
        name = input('Enter Name : ')
        surname = input("Enter Surname : ")
        designation = input("Enter Designation : ")
        address = input("Enter Address : ")

        if name.strip() == '':
            name = emp_detail[1]
        if surname.strip() == '':
            surname = emp_detail[2]
        if designation.strip() == '':
            designation = emp_detail[4]
        if address.strip() == '':
            address = ','.join(emp_detail[6:])


        update_record(emp_id,name, surname,designation,address)

        
        print('========================================')

